#! /bin/bash

set -e

omarchy-show-logo

echo "Uninstalling theme hook.."

rm -rf /tmp/theme-hook/
rm -rf $HOME/.local/share/omarchy/bin/theme-hook-update
rm -rf $HOME/.config/omarchy/hooks/theme-set.d/
rm -rf $HOME/.config/omarchy/hooks/plugins/
rm -rf $HOME/.config/omarchy/hooks/theme-set

echo "Attempting to unapply theme hook.."
if command -v python >/dev/null 2>&1; then
    cd $HOME/.local/share/steam-adwaita && ./install.py --uninstall > /dev/null 2>&1
fi
if command -v spicetify >/dev/null 2>&1; then
    spicetify restore
fi
gsettings set org.gnome.desktop.interface gtk-theme Adwaita

echo "Uninstalled theme hook!"

omarchy-show-done
