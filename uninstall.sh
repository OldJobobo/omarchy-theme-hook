#! /bin/bash

set -e

omarchy-show-logo

echo "Uninstalling thpm.."

rm -rf /tmp/theme-hook/
rm -f $HOME/.local/share/omarchy/bin/thpm
rm -f $HOME/.local/share/omarchy/bin/thctl
rm -rf $HOME/.config/omarchy/hooks/theme-set.d/
rm -rf $HOME/.config/omarchy/hooks/theme-set

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
