#!/bin/bash
set -euo pipefail

THEME_NAME="${1:-}"
THEME_DIR="$HOME/.config/omarchy/themes/$THEME_NAME"
WAYBAR_THEME_DIR="$THEME_DIR/waybar-theme"
WAYBAR_DIR="$HOME/.config/waybar"
BACKUP_DIR="$HOME/.config/waybar-backups/$(date +%Y%m%d-%H%M%S)"

if [[ -d "$WAYBAR_THEME_DIR" ]]; then
    mkdir -p "$WAYBAR_DIR" "$BACKUP_DIR"

    for file in config.jsonc style.css; do
        if [[ -L "$WAYBAR_DIR/$file" ]]; then
            rm -f "$WAYBAR_DIR/$file"
        elif [[ -e "$WAYBAR_DIR/$file" ]]; then
            cp -a "$WAYBAR_DIR/$file" "$BACKUP_DIR/$file"
        fi
        if [[ -e "$WAYBAR_THEME_DIR/$file" ]]; then
            ln -snf "$WAYBAR_THEME_DIR/$file" "$WAYBAR_DIR/$file"
        fi
    done

    if pgrep -x waybar >/dev/null; then
        omarchy-restart-waybar
    fi
fi
