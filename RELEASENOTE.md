# Theme Hook Plugin Manager Release

This fork exists because Omarchy theming is moving quickly, while the original `omarchy-theme-hook` repo appears to have gone stale. `thpm` keeps the idea alive as an actively maintained, Omarchy-focused plugin manager with newer app support and fixes for rough edges that affect daily use.

## New App Support

This release expands the bundled plugin set with several integrations that were missing from the original project:

- **SwayNC** notification theming
- **Foot live colors** for updating existing Foot terminals
- **Obsidian Terminal** plugin colors
- **cliamp** theme support

The supported app list now includes browsers, editors, desktop UI, terminal tools, and game/media apps, with plugins managed through the `thpm` CLI.

## Important Fixes

This release also fixes several issues that could make the hook frustrating or brittle:

- Disabled plugins now stay disabled after `thpm update`
- Missing `colors.toml` now reports the intended error instead of failing with `error: command not found`
- `thpm uninstall` now works as documented
- Uninstall cleanup is best-effort, so missing optional integrations do not abort removal
- Installer no longer requires `gum`; it falls back to a plain shell prompt
- `thpm enable <name>` and `thpm disable <name>` now warn when the plugin name does not exist
- README now documents that updates replace bundled plugin files

## Why This Fork

The original [`imbypass/omarchy-theme-hook`](https://github.com/imbypass/omarchy-theme-hook) laid the groundwork, but Omarchy's theme format and ecosystem have kept evolving. This fork focuses on keeping the hook useful for current Omarchy systems, expanding plugin coverage, and making plugin management predictable.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/install.sh | bash
```

## Update

```bash
thpm update
```

## Basic Usage

```bash
thpm list
thpm enable firefox
thpm disable spotify
thpm run
```

## Credits

Based on [`imbypass/omarchy-theme-hook`](https://github.com/imbypass/omarchy-theme-hook), with continued maintenance, expanded plugin support, and fixes for current Omarchy usage.
