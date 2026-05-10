# Release Notes

## Unreleased

### Added

- Added a shared `thpm` hook runtime at `~/.local/share/thpm/lib/theme-env.sh`
  so bundled plugins can run directly as native Omarchy `theme-set.d` hooks.
- Added bundled tmux theme support through `theme-set.d/10-tmux.sh`.
  Themes can now ship `tmux.conf`; when present, `thpm` installs it as
  `~/.config/tmux/omarchy-theme.conf`, ensures the user's tmux config sources
  that stable file once, and reloads running tmux sessions.

### Fixed

- Aligned plugin execution with Omarchy's native `.d` hook runner. Plugins now
  source their own theme environment, and disabled plugins use Omarchy's
  `.sample` skip convention instead of executable bits.
- Removed stale tmux theme state when switching to a theme that does not ship
  `tmux.conf`. The tmux plugin now removes its managed source line and copied
  theme file before reloading the user's tmux config.
