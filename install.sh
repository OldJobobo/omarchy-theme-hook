#!/usr/bin/env bash

set -e

# Install prerequisites
if ! pacman -Qi "adw-gtk-theme" &>/dev/null; then
    if command -v gum >/dev/null 2>&1; then
        gum style --border normal --border-foreground 6 --padding "1 2" \
        "\"adw-gtk-theme\" is required to theme GTK applications."

        if gum confirm "Would you like to install \"adw-gtk-theme\"?"; then
            sudo pacman -S adw-gtk-theme
        fi
    else
        echo "\"adw-gtk-theme\" is required to theme GTK applications."
        read -r -p "Would you like to install \"adw-gtk-theme\"? [y/N] " install_adw_gtk
        case "$install_adw_gtk" in
            y|Y|yes|YES) sudo pacman -S adw-gtk-theme ;;
        esac
    fi
fi

# Remove any old temp files
rm -rf /tmp/theme-hook/

disabled_plugins=()
plugin_dir="$HOME/.config/omarchy/hooks/theme-set.plugins.d"
legacy_plugin_dir="$HOME/.config/omarchy/hooks/theme-set.d"

for existing_plugin_dir in "$plugin_dir" "$legacy_plugin_dir"; do
    if [[ -d "$existing_plugin_dir" ]]; then
        for plugin in "$existing_plugin_dir"/*.sh; do
            [[ -f "$plugin" && ! -x "$plugin" ]] || continue
            disabled_plugins+=("$(basename "$plugin")")
        done
    fi
done

# Clone the Theme Hook Plugin Manager repository
echo -e "Downloading thpm.."
git clone --branch thpm --depth 1 https://github.com/OldJobobo/theme-hook-plugin-manager.git /tmp/theme-hook > /dev/null 2>&1

# Remove legacy aliases from previous installs
rm -f $HOME/.local/share/omarchy/bin/theme-hook-update > /dev/null 2>&1
rm -f $HOME/.local/share/omarchy/bin/thctl > /dev/null 2>&1
rm -f $HOME/.local/share/omarchy/bin/thpm > /dev/null 2>&1

# Install the thpm CLI
mkdir -p $HOME/.local/bin
mv -f /tmp/theme-hook/thpm $HOME/.local/bin/thpm
chmod +x $HOME/.local/bin/thpm

# Copy theme-set hook to Omarchy hooks directory
mkdir -p "$HOME/.config/omarchy/hooks"
mv -f /tmp/theme-hook/theme-set $HOME/.config/omarchy/hooks/

# Create managed plugin directory and move any legacy plugins out of
# theme-set.d. Omarchy 3.8+ runs files in theme-set.d directly after the
# main hook, so keeping thpm plugins there runs them twice and without the
# helper functions exported by theme-set.
mkdir -p "$plugin_dir" "$legacy_plugin_dir"
for plugin in "$legacy_plugin_dir"/*.sh; do
    [[ -f "$plugin" ]] || continue
    mv -f "$plugin" "$plugin_dir/"
done
mv -f /tmp/theme-hook/theme-set.d/* "$plugin_dir/"

# Remove any new temp files
rm -rf /tmp/theme-hook

# Update permissions
chmod +x $HOME/.config/omarchy/hooks/theme-set
for plugin in "$plugin_dir"/*; do
    [[ -f "$plugin" ]] || continue
    chmod +x "$plugin"
done

for plugin in "${disabled_plugins[@]}"; do
    if [[ -f "$plugin_dir/$plugin" ]]; then
        chmod -x "$plugin_dir/$plugin"
    fi
done

# Run the theme-set hook to apply the current theme
echo "Running theme-set hook.."
omarchy-hook theme-set

omarchy-show-done
