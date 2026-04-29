#!/bin/bash

if ! command -v tmux >/dev/null 2>&1; then
    skipped "tmux"
fi

source_file="$HOME/.config/omarchy/current/theme/tmux.conf"
target_file="$HOME/.config/tmux/omarchy-theme.conf"
source_line="source-file ~/.config/tmux/omarchy-theme.conf"

if [[ ! -f "$source_file" ]]; then
    skipped "tmux.conf"
fi

mkdir -p "$(dirname "$target_file")"
install -m 600 "$source_file" "$target_file"

if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    config_file="$HOME/.config/tmux/tmux.conf"
elif [[ -f "$HOME/.tmux.conf" ]]; then
    config_file="$HOME/.tmux.conf"
else
    config_file="$HOME/.config/tmux/tmux.conf"
    touch "$config_file"
fi

if ! grep -Fxq "$source_line" "$config_file"; then
    printf '\n%s\n' "$source_line" >> "$config_file"
fi

tmux source-file "$target_file" >/dev/null 2>&1 || true

success "tmux theme updated!"
