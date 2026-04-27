#!/bin/bash
# Update Obsidian terminal plugin xterm.js theme colors on Omarchy theme switch.
# Reads color vars exported by the parent theme-set hook (no # prefix).

DATA_JSON="$HOME/Documents/My Vault/.obsidian/plugins/terminal/data.json"

[[ -f "$DATA_JSON" ]] || skipped "Obsidian terminal plugin data.json"

python3 - "$DATA_JSON" <<PYEOF
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

import os
def c(var):
    val = os.environ.get(var, "")
    return "#" + val if val else None

theme = {
    "background":          c("primary_background"),
    "foreground":          c("primary_foreground"),
    "cursor":              c("cursor_color"),
    "cursorAccent":        c("primary_background"),
    "selectionBackground": c("selection_background"),
    "selectionForeground": c("selection_foreground"),
    "black":               c("normal_black"),
    "red":                 c("normal_red"),
    "green":               c("normal_green"),
    "yellow":              c("normal_yellow"),
    "blue":                c("normal_blue"),
    "magenta":             c("normal_magenta"),
    "cyan":                c("normal_cyan"),
    "white":               c("normal_white"),
    "brightBlack":         c("bright_black"),
    "brightRed":           c("bright_red"),
    "brightGreen":         c("bright_green"),
    "brightYellow":        c("bright_yellow"),
    "brightBlue":          c("bright_blue"),
    "brightMagenta":       c("bright_magenta"),
    "brightCyan":          c("bright_cyan"),
    "brightWhite":         c("bright_white"),
}

# Drop any keys that failed to resolve
theme = {k: v for k, v in theme.items() if v and v != "#"}

data.setdefault("terminalOptions", {})["theme"] = theme

with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF

success "Obsidian terminal plugin colors updated"
