#!/usr/bin/env bash
source "${THPM_THEME_ENV:-$HOME/.local/share/thpm/lib/theme-env.sh}"
# Update Obsidian Terminal plugin xterm.js theme colors on Omarchy theme switch.
# Reads color vars exported by the parent theme-set hook (no # prefix).

if [[ -z "${primary_background:-}" || -z "${primary_foreground:-}" ]]; then
    if declare -F skipped >/dev/null 2>&1; then
        skipped "Obsidian Terminal plugin theme colors"
    fi
    exit 0
fi

mapfile -d '' DATA_JSON_FILES < <(python3 <<'PYEOF'
import json
import os
from pathlib import Path

home = Path(os.environ.get("HOME", str(Path.home()))).expanduser()
seen = set()
matches = []

def add(path):
    path = Path(path).expanduser()
    try:
        resolved = path.resolve()
    except OSError:
        resolved = path
    key = str(resolved)
    if key in seen:
        return
    seen.add(key)
    if path.is_file():
        matches.append(path)

def add_vault(vault):
    add(Path(vault) / ".obsidian" / "plugins" / "terminal" / "data.json")

for value in (
    os.environ.get("OBSIDIAN_TERMINAL_DATA_JSON", ""),
    os.environ.get("OBSIDIAN_TERMINAL_DATA", ""),
):
    for item in value.split(":"):
        if item:
            add(item)

for value in (
    os.environ.get("OBSIDIAN_VAULT_PATH", ""),
    os.environ.get("OBSIDIAN_VAULT", ""),
):
    for item in value.split(":"):
        if item:
            add_vault(item)

config_home = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
config_files = [
    config_home / "obsidian" / "obsidian.json",
    home / ".config" / "obsidian" / "obsidian.json",
]

for config_file in config_files:
    if not config_file.is_file():
        continue
    try:
        data = json.loads(config_file.read_text())
    except (OSError, json.JSONDecodeError):
        continue
    for vault in data.get("vaults", {}).values():
        path = vault.get("path") if isinstance(vault, dict) else None
        if path:
            add_vault(path)

for root in (
    home / "Documents",
    home / "Desktop",
    home / "Projects",
    home / "Notes",
    home / "Vaults",
):
    if not root.is_dir():
        continue
    for plugin_data in root.glob("*/.obsidian/plugins/terminal/data.json"):
        add(plugin_data)

for path in matches:
    print(path, end="\0")
PYEOF
)

[[ ${#DATA_JSON_FILES[@]} -gt 0 ]] || skipped "Obsidian Terminal plugin data.json"

python3 - "${DATA_JSON_FILES[@]}" <<PYEOF
import json, sys

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

for path in sys.argv[1:]:
    with open(path) as f:
        data = json.load(f)

    data.setdefault("terminalOptions", {})["theme"] = theme

    with open(path, "w") as f:
        json.dump(data, f, indent=2)
PYEOF

success "Obsidian Terminal plugin colors updated (${#DATA_JSON_FILES[@]})"
