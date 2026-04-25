<div align="center">

# Theme Hook Plugin Manager

**A plugin manager for Omarchy's theme-set hook.** Run any number of small, independent theming tasks every time you change your Omarchy theme.

</div>

> **Not affiliated with Omarchy.** This project is a fork of [imbypass/omarchy-theme-hook](https://github.com/imbypass/omarchy-theme-hook), reframed around a plugin-manager model. The upstream presents itself as *a* theme hook; in practice it is a runner that calls many independent scripts. This fork makes that model explicit: a single runner, a directory of plugins, a CLI to manage them.

## Why

Omarchy already provides a `theme-set` hook that fires whenever you switch themes. What it doesn't provide is a way to register *multiple* things to happen on that hook — theme Discord, theme GTK, theme Spotify, theme your own custom app, and so on.

`thpm` plugs into Omarchy's `theme-set` hook with a small dispatcher and a directory of executable scripts. Each script — a **plugin** — is responsible for one concern (one app, one task). You can enable, disable, add, or replace plugins independently without touching the dispatcher.

## How it works

```
Omarchy theme change
        │
        ▼
omarchy-hook theme-set                  ← Omarchy's built-in hook
        │
        ▼
~/.config/omarchy/hooks/theme-set       ← thpm dispatcher
        │  reads colors.toml, exports color vars + helpers
        ▼
~/.config/omarchy/hooks/theme-set.d/    ← plugin directory
   ├── 00-fish.sh
   ├── 10-gtk.sh
   ├── 30-vscode.sh
   ├── 40-firefox.sh
   └── …
```

Plugins run in lexicographic order, so the numeric prefix controls execution order. A plugin is "enabled" when its file is executable and "disabled" when it isn't.

## Install

```
curl -fsSL https://raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/install.sh | bash
```

## Update

```
thpm update
```

Or re-run the install command above.

## CLI: `thpm`

| Command | Description |
| --- | --- |
| `thpm list` | Show enabled and disabled plugins |
| `thpm enable <name>` | Enable a plugin |
| `thpm disable <name>` | Disable a plugin |
| `thpm run` | Run the theme-set hook now |
| `thpm open` | Open the plugin directory in your file manager |
| `thpm update` | Reinstall to pull the latest version |
| `thpm uninstall` | Remove `thpm` |
| `thpm help` | Show help |

Enabling and disabling is just `chmod +x` / `chmod -x` under the hood — you can do it manually if you prefer.

## Bundled plugins

- Cava
- Cursor
- Discord
- Firefox
- Fish
- Fzf
- GTK (requires `adw-gtk-theme` from the AUR)
- Heroic
- nwg-dock-hyprland
- QT6
- Qutebrowser
- Spotify
- Steam
- Superfile
- Typora
- Vicinae
- VS Code
- Waybar
- Windsurf
- Zed
- Zen Browser (experimental — requires manual enabling of legacy userchrome styling)

## Writing your own plugin

A plugin is any executable shell script in `~/.config/omarchy/hooks/theme-set.d/`. The dispatcher exports color values and helper functions for you to use:

**Color variables** (hex, no `#`): `primary_background`, `primary_foreground`, `cursor_color`, `selection_background`, `selection_foreground`, `normal_black` … `normal_white`, `bright_black` … `bright_white`. Each also has an `rgb_` prefixed form (e.g. `rgb_normal_blue`) returning `r, g, b`.

**Helpers:** `success`, `warning`, `error`, `skipped`, `hex2rgb`, `rgb2hex`, `change_shade`, `require_restart <process-name>`.

```bash
#!/bin/bash
# 50-myapp.sh

config="$HOME/.config/myapp/theme.conf"
[[ ! -f "$config" ]] && skipped "myapp"

cat > "$config" <<EOF
background = #$primary_background
foreground = #$primary_foreground
accent     = #$normal_blue
EOF

require_restart "myapp"
success "myapp themed"
```

Name with a numeric prefix to control ordering: `10-` early, `40-` late.

## Uninstall

```
curl -fsSL https://raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/uninstall.sh | bash
```

## FAQ

#### I installed thpm but my apps aren't theming.

Some apps need a one-time manual theme selection. After install, set the theme to "Omarchy" in each app's settings panel.

#### Firefox / Zen Browser isn't theming.

Open `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`, and restart the browser.

#### Discord isn't theming.

Use a third-party client (Vesktop, Equibop), apply a theme in Omarchy, then enable the Omarchy theme in your Discord client's theme settings.

#### Spotify isn't theming or stopped theming.

Make sure Spicetify is properly installed — see [the Spicetify Linux note](https://spicetify.app/docs/advanced-usage/installation#note-for-linux-users). If it stopped working after a Spotify update, run `spicetify restore backup apply`, or reinstall Spotify and Spicetify and run `spicetify backup apply`.

#### `colors.toml not found` error.

Omarchy 3.3+ requires themes to ship a `colors.toml` file. Update your theme to a 3.3-compatible version, or add a valid `colors.toml` to the theme directory.

## Contributing

Plugin contributions are welcome. If you have a script for an app that isn't bundled, open a PR. Keep plugins to a single script and avoid heavy dependencies.

## Credits

Forked from [imbypass/omarchy-theme-hook](https://github.com/imbypass/omarchy-theme-hook). Upstream contributors and plugin authors are credited via git history.
