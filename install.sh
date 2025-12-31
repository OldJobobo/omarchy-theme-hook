#! /bin/bash

set -e

omarchy-show-logo

# Install prerequisites
if ! pacman -Qi "adw-gtk-theme" &>/dev/null; then
    gum style --border normal --border-foreground 6 --padding "1 2" \
    "\"adw-gtk-theme\" is required to theme GTK applications."

    if gum confirm "Would you like to install \"adw-gtk-theme\"?"; then
        sudo pacman -S adw-gtk-theme
    fi
fi

# Remove any old temp files
rm -rf /tmp/theme-hook/

# Clone the Omarchy theme hook repository
echo -e "Cloning Omarchy theme hook repository.."
git clone https://github.com/imbypass/omarchy-theme-hook.git /tmp/theme-hook > /dev/null

# Create an update alias
mv -f /tmp/theme-hook/install.sh $HOME/.local/share/omarchy/bin/theme-hook-update
chmod +x $HOME/.local/share/omarchy/bin/theme-hook-update

# Copy theme-set hook to Omarchy hooks directory
mv -f /tmp/theme-hook/theme-set $HOME/.config/omarchy/hooks/

# Create theme hook directory and copy scripts
mkdir -p $HOME/.config/omarchy/hooks/theme-set.d/
mv -f /tmp/theme-hook/theme-set.d/* $HOME/.config/omarchy/hooks/theme-set.d/

# Create plugin hook directory and copy scripts
if [[ -d /tmp/theme-hook/plugins/theme-set.d ]]; then
    mkdir -p $HOME/.config/omarchy/hooks/plugins/theme-set.d/
    mv -f /tmp/theme-hook/plugins/theme-set.d/* $HOME/.config/omarchy/hooks/plugins/theme-set.d/
fi

# Remove any new temp files
rm -rf /tmp/theme-hook

# Update permissions
chmod +x $HOME/.config/omarchy/hooks/theme-set
chmod +x $HOME/.config/omarchy/hooks/theme-set.d/*
if [[ -d $HOME/.config/omarchy/hooks/plugins/theme-set.d ]]; then
    chmod +x $HOME/.config/omarchy/hooks/plugins/theme-set.d/*
fi

# Update Omarchy theme
echo "Executing theme hook.."
omarchy-hook theme-set

omarchy-show-done
