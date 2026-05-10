# Plugin Guide

This guide is for writing local `thpm` plugins.

User setup and normal commands live in the main [README](../README.md).

## Plugin Location

Installed plugins live in:

```text
~/.config/omarchy/hooks/theme-set.plugins.d/
```

Bundled plugin source lives in this repository under:

```text
theme-set.d/
```

Plugin filenames should use a numeric prefix so their order is predictable:

```text
50-myapp.sh
```

Lower numbers run earlier. Higher numbers run later.

## Enable and Disable

A plugin is enabled when the file is executable. It is disabled when the file is not executable.

Use `thpm` for normal toggling:

```bash
thpm enable myapp
thpm disable myapp
```

## Available Theme Values

Plugins run with Omarchy theme colors exported as shell variables. Hex values do not include `#`.

Common values:

- `primary_background`
- `primary_foreground`
- `cursor_color`
- `selection_background`
- `selection_foreground`
- `normal_black` through `normal_white`
- `bright_black` through `bright_white`

RGB companion values are also available with an `rgb_` prefix, such as:

```bash
rgb_normal_blue
rgb_primary_background
```

RGB values are formatted as:

```text
r, g, b
```

## Helper Functions

Plugins can use these helper functions:

| Helper | Use |
| --- | --- |
| `success "message"` | Print a success message |
| `warning "message"` | Print a warning |
| `error "message"` | Print an error and stop |
| `skipped "AppName"` | Skip cleanly when an app or required file is missing |
| `hex2rgb <hex>` | Convert hex to `r, g, b` |
| `rgb2hex <r> <g> <b>` | Convert RGB values to hex |
| `change_shade <hex> <amount>` | Lighten or darken a color |
| `require_restart <process-name>` | Show a restart notification if that process is running |

Use `skipped` for missing apps or optional files. Use `error` only when the plugin actually failed.

## Example Plugin

```bash
#!/bin/bash

if ! command -v myapp >/dev/null 2>&1; then
    skipped "myapp"
fi

config="$HOME/.config/myapp/theme.conf"
mkdir -p "$(dirname "$config")"

cat > "$config" <<EOF
background = #$primary_background
foreground = #$primary_foreground
accent = #$normal_blue
EOF

require_restart "myapp"
success "myapp theme updated!"
```

Save it as:

```text
~/.config/omarchy/hooks/theme-set.plugins.d/50-myapp.sh
```

Then enable it:

```bash
chmod +x ~/.config/omarchy/hooks/theme-set.plugins.d/50-myapp.sh
thpm run
```

## Color Source

`thpm` reads colors from:

```text
~/.config/omarchy/current/theme/colors.toml
```

This matches Omarchy 3.3+ themes.
