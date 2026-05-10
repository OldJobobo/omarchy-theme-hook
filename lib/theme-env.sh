#!/usr/bin/env bash

# Shared runtime for thpm theme hooks. Omarchy runs hooks in
# ~/.config/omarchy/hooks/theme-set.d directly, so every bundled plugin
# sources this file to load the current theme colors and helper functions.
input_file="${THPM_COLORS_FILE:-$HOME/.config/omarchy/current/theme/colors.toml}"

success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

skipped() {
    echo -e "\033[0;34m[SKIPPED]\e[0m $1 not found. Skipping.."
    exit 0
}

warning() {
    echo -e "\033[0;33m[WARNING]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit 1
}

if [[ ! -f "$input_file" ]]; then
    error "colors.toml not found at $input_file. Ensure your theme is compatible with Omarchy 3.3+ and includes colors.toml."
fi

extract_color() {
    local color_name="$1"
    awk -v color="$color_name" '
        $1 == color && /=/ {
            if (match($0, /#([0-9a-fA-F]{6})/)) {
                print substr($0, RSTART + 1, 6)
                exit
            }
        }
    ' "$input_file"
}

hex2rgb() {
    local hex_input=$1
    local r=$((16#${hex_input:0:2}))
    local g=$((16#${hex_input:2:2}))
    local b=$((16#${hex_input:4:2}))
    echo "$r, $g, $b"
}

rgb2hex() {
    local r=$1
    local g=$2
    local b=$3
    printf "%02x%02x%02x" "$r" "$g" "$b"
}

clamp_rgb() {
    local value=$1
    if (( value < 0 )); then
        echo 0
    elif (( value > 255 )); then
        echo 255
    else
        echo "$value"
    fi
}

change_shade() {
    local hex_input=$1
    local shade=$2
    local r=$((16#${hex_input:0:2}))
    local g=$((16#${hex_input:2:2}))
    local b=$((16#${hex_input:4:2}))

    r=$(clamp_rgb $((r + shade)))
    g=$(clamp_rgb $((g + shade)))
    b=$(clamp_rgb $((b + shade)))

    rgb2hex "$r" "$g" "$b"
}

require_restart() {
    local process_name="$1"
    local display_name="${2:-${process_name^}}"

    if command -v pgrep >/dev/null 2>&1 && pgrep -x "$process_name" >/dev/null; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Theme Hook Plugin Manager" "$display_name requires a restart to apply theme."
        else
            warning "$display_name requires a restart to apply theme."
        fi
    fi
}

primary_foreground=$(extract_color "foreground")
primary_background=$(extract_color "background")
cursor_color=$(extract_color "cursor")
selection_foreground=$(extract_color "selection_foreground")
selection_background=$(extract_color "selection_background")
normal_black=$(extract_color "color0")
normal_red=$(extract_color "color1")
normal_green=$(extract_color "color2")
normal_yellow=$(extract_color "color3")
normal_blue=$(extract_color "color4")
normal_magenta=$(extract_color "color5")
normal_cyan=$(extract_color "color6")
normal_white=$(extract_color "color7")
bright_black=$(extract_color "color8")
bright_red=$(extract_color "color9")
bright_green=$(extract_color "color10")
bright_yellow=$(extract_color "color11")
bright_blue=$(extract_color "color12")
bright_magenta=$(extract_color "color13")
bright_cyan=$(extract_color "color14")
bright_white=$(extract_color "color15")

export primary_background primary_foreground cursor_color selection_foreground selection_background
export normal_black normal_red normal_green normal_yellow normal_blue normal_magenta normal_cyan normal_white
export bright_black bright_red bright_green bright_yellow bright_blue bright_magenta bright_cyan bright_white

rgb_primary_foreground=$(hex2rgb "$primary_foreground")
rgb_primary_background=$(hex2rgb "$primary_background")
rgb_normal_black=$(hex2rgb "$normal_black")
rgb_normal_red=$(hex2rgb "$normal_red")
rgb_normal_green=$(hex2rgb "$normal_green")
rgb_normal_yellow=$(hex2rgb "$normal_yellow")
rgb_normal_blue=$(hex2rgb "$normal_blue")
rgb_normal_magenta=$(hex2rgb "$normal_magenta")
rgb_normal_cyan=$(hex2rgb "$normal_cyan")
rgb_normal_white=$(hex2rgb "$normal_white")
rgb_bright_black=$(hex2rgb "$bright_black")
rgb_bright_red=$(hex2rgb "$bright_red")
rgb_bright_green=$(hex2rgb "$bright_green")
rgb_bright_yellow=$(hex2rgb "$bright_yellow")
rgb_bright_blue=$(hex2rgb "$bright_blue")
rgb_bright_magenta=$(hex2rgb "$bright_magenta")
rgb_bright_cyan=$(hex2rgb "$bright_cyan")
rgb_bright_white=$(hex2rgb "$bright_white")

export rgb_primary_foreground rgb_primary_background
export rgb_normal_black rgb_normal_red rgb_normal_green rgb_normal_yellow rgb_normal_blue rgb_normal_magenta rgb_normal_cyan rgb_normal_white
export rgb_bright_black rgb_bright_red rgb_bright_green rgb_bright_yellow rgb_bright_blue rgb_bright_magenta rgb_bright_cyan rgb_bright_white
