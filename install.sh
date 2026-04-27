#! /bin/bash

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
if [[ -d "$HOME/.config/omarchy/hooks/theme-set.d" ]]; then
    for plugin in "$HOME"/.config/omarchy/hooks/theme-set.d/*.sh; do
        [[ -f "$plugin" && ! -x "$plugin" ]] || continue
        disabled_plugins+=("$(basename "$plugin")")
    done
fi

# Clone the Theme Hook Plugin Manager repository
echo -e "Downloading thpm.."
git clone --branch thpm --depth 1 https://github.com/OldJobobo/theme-hook-plugin-manager.git /tmp/theme-hook > /dev/null 2>&1

# Remove legacy aliases from previous installs
rm -f $HOME/.local/share/omarchy/bin/theme-hook-update > /dev/null 2>&1
rm -f $HOME/.local/share/omarchy/bin/thctl > /dev/null 2>&1

# Install the thpm CLI
mv -f /tmp/theme-hook/thpm $HOME/.local/share/omarchy/bin/thpm
chmod +x $HOME/.local/share/omarchy/bin/thpm

# Copy theme-set hook to Omarchy hooks directory
mv -f /tmp/theme-hook/theme-set $HOME/.config/omarchy/hooks/

# Create theme hook directory and copy scripts
mkdir -p $HOME/.config/omarchy/hooks/theme-set.d/
mv -f /tmp/theme-hook/theme-set.d/* $HOME/.config/omarchy/hooks/theme-set.d/

# Remove any new temp files
rm -rf /tmp/theme-hook

# Update permissions
chmod +x $HOME/.config/omarchy/hooks/theme-set
chmod +x $HOME/.config/omarchy/hooks/theme-set.d/*

for plugin in "${disabled_plugins[@]}"; do
    if [[ -f "$HOME/.config/omarchy/hooks/theme-set.d/$plugin" ]]; then
        chmod -x "$HOME/.config/omarchy/hooks/theme-set.d/$plugin"
    fi
done

# Run the theme-set hook to apply the current theme
echo "Running theme-set hook.."
omarchy-hook theme-set

omarchy-show-done
