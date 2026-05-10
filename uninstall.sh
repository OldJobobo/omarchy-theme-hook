#!/usr/bin/env bash

set -e

omarchy-show-logo

echo "Uninstalling thpm.."

rm -rf /tmp/theme-hook/
rm -f $HOME/.local/bin/thpm
rm -f $HOME/.local/share/omarchy/bin/thpm
rm -f $HOME/.local/share/omarchy/bin/thctl
rm -f $HOME/.local/share/thpm/lib/theme-env.sh
rmdir $HOME/.local/share/thpm/lib $HOME/.local/share/thpm 2>/dev/null || true

if [[ -f "$HOME/.config/omarchy/hooks/theme-set" ]] && grep -Eq 'Omarchy 3\.3\+ uses colors\.toml|Compatibility shim for older thpm installs' "$HOME/.config/omarchy/hooks/theme-set"; then
    rm -f "$HOME/.config/omarchy/hooks/theme-set"
fi

bundled_plugins=(
    00-fish.sh
    00-fzf.sh
    10-discord.sh
    10-gtk.sh
    10-qt6ct.sh
    10-spotify.sh
    10-superfile.sh
    10-tmux.sh
    10-vicinae.sh
    15-typora.sh
    20-nwg-dock-hyprland.sh
    20-zed.sh
    25-swaync.sh
    26-foot-live-colors.sh
    30-cursor.sh
    30-vscode.sh
    30-windsurf.sh
    35-obsidian-terminal.sh
    40-cava.sh
    40-firefox.sh
    40-qutebrowser.sh
    40-steam.sh
    40-zen.sh
    50-cliamp.sh
    50-heroic.sh
)

for plugin in "${bundled_plugins[@]}"; do
    rm -f "$HOME/.config/omarchy/hooks/theme-set.d/$plugin"
    rm -f "$HOME/.config/omarchy/hooks/theme-set.d/$plugin.sample"
done
rmdir "$HOME/.config/omarchy/hooks/theme-set.d" 2>/dev/null || true

echo "Attempting to revert applied themes.."

# Remove Steam theme
if command -v python >/dev/null 2>&1 && [[ -d "$HOME/.local/share/steam-adwaita" ]]; then
    (cd "$HOME/.local/share/steam-adwaita" && ./install.py --uninstall) > /dev/null 2>&1 || true
fi

# Remove Spotify theme
if command -v spicetify >/dev/null 2>&1; then
    spicetify restore > /dev/null 2>&1 || true
fi

# Remove GTK theme
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita > /dev/null 2>&1 || true
fi

# Remove Qutebrowser theme
if command -v qutebrowser >/dev/null 2>&1; then
    rm -rf "$HOME/.config/qutebrowser/omarchy"
    config_file="$HOME/.config/qutebrowser/config.py"
    if [[ -f "$config_file" ]]; then
        sed -i '/import omarchy\.draw/d' "$config_file"
        sed -i '/omarchy\.draw\.apply(c)/d' "$config_file"
    fi
fi

# Remove Vicinae theme
if command -v vicinae >/dev/null 2>&1; then
    vicinae theme set vicinae-dark > /dev/null 2>&1 || true
fi

echo "Uninstalled thpm!"

omarchy-show-done
