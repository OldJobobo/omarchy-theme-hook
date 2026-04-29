<div align="center">

# Theme Hook Plugin Manager

**Make your Omarchy theme follow you across the desktop.**

`thpm` applies your current Omarchy colors to supported apps whenever you change themes.

</div>

> **Not affiliated with Omarchy.** Theme Hook Plugin Manager is an independent project built for Omarchy users.

## Why Use It

Omarchy already gives you a strong system theme. `thpm` carries that theme into the apps that do not automatically follow it: browsers, editors, launchers, media apps, terminal tools, notification UI, and more.

Install it once, keep the plugins you want enabled, and your apps update when your Omarchy theme changes. Apps you do not have installed are skipped.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/install.sh | bash
```

The installer applies your current Omarchy theme after setup.

### Install GTK Theme Dependency

The GTK plugin requires Omarchy's Adwaita-compatible GTK theme package:

```bash
omarchy-pkg-add adw-gtk-theme
```

You can also install it from the Omarchy menu with `Super + Alt + Space`:

```text
Install > Package > adw-gtk-theme
```

The `thpm` installer checks for `adw-gtk-theme` and can prompt to install it if it is missing.

## Requirements

- Omarchy
- An Omarchy 3.3+ theme with `colors.toml`
- `adw-gtk-theme` for GTK app theming
- The apps you want to theme installed on your system

Some apps need a one-time theme selection inside their own settings. See [Troubleshooting](#troubleshooting) for common cases.

## Supported Apps

**Browsers**

- Firefox
- Qutebrowser
- Zen Browser

**Editors and writing apps**

- Cursor
- Obsidian Terminal plugin
- Typora
- VS Code
- Windsurf
- Zed

**Desktop and UI**

- Discord clients using Vencord-compatible themes
- GTK apps
- nwg-dock-hyprland
- Qt6 apps using qt6ct
- SwayNC
- Vicinae

**Terminal and CLI**

- cliamp
- Cava
- Fish
- Foot live colors
- fzf
- Superfile

**Games and media**

- Heroic Games Launcher
- Spotify using Spicetify
- Steam

## Use

List your plugins:

```bash
thpm list
```

Enable or disable a plugin:

```bash
thpm enable firefox
thpm disable spotify
```

Apply the current theme again:

```bash
thpm run
```

Open the plugin folder:

```bash
thpm open
```

## Commands

| Command | What it does |
| --- | --- |
| `thpm list` | Show enabled and disabled plugins |
| `thpm enable <name>` | Enable a plugin |
| `thpm disable <name>` | Disable a plugin |
| `thpm run` | Apply the current Omarchy theme now |
| `thpm open` | Open the plugin folder |
| `thpm update` | Update `thpm` |
| `thpm remove` | Uninstall `thpm` |
| `thpm help` | Show command help |

## What Changed From the Original Project

Theme Hook Plugin Manager builds on the original [omarchy-theme-hook](https://github.com/imbypass/omarchy-theme-hook) idea, but expands it into a managed plugin tool for everyday use.

- A dedicated `thpm` command
- Plugin listing, enabling, and disabling
- More bundled app integrations
- Update and uninstall commands
- Omarchy 3.3+ `colors.toml` support
- Clearer setup and troubleshooting docs

## Custom Plugins

Custom plugins live in:

```text
~/.config/omarchy/hooks/theme-set.d/
```

Run `thpm open` to open that folder. A plugin is enabled when its script is executable and disabled when it is not.

For plugin authoring details, see [docs/plugins.md](docs/plugins.md).

## Troubleshooting

#### I installed `thpm`, but an app is not changing theme.

Check that the plugin is enabled:

```bash
thpm list
```

Then open the app and choose the Omarchy theme in that app's settings if it has a manual theme selector.

#### Firefox or Zen Browser is not changing theme.

Open `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`, and restart the browser.

#### Discord is not changing theme.

Use a client with Vencord-compatible themes, such as Vesktop or Equibop. After applying an Omarchy theme, enable the Omarchy theme in your Discord client's theme settings.

#### Spotify is not changing theme.

Make sure Spicetify is installed and working. If Spotify stopped theming after an update, run:

```bash
spicetify restore backup apply
```

Then apply your Omarchy theme again:

```bash
thpm run
```

#### I see a `colors.toml not found` error.

Use an Omarchy 3.3-compatible theme. The theme must include a valid `colors.toml` file.

## Update

```bash
thpm update
```

You can also re-run the install command.

Updating replaces bundled plugin files with the latest versions. If you want to customize a plugin, copy it to a new filename in the plugin folder first.

## Uninstall

```bash
thpm remove
```

Or run:

```bash
curl -fsSL https://raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/uninstall.sh | bash
```

## Credits

Based on [imbypass/omarchy-theme-hook](https://github.com/imbypass/omarchy-theme-hook). This project expands the original hook approach into a plugin-managed Omarchy theming tool.
