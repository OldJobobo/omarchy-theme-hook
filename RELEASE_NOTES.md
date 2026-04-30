# Release Notes

## Unreleased

### Added

- Added bundled tmux theme support through `theme-set.d/10-tmux.sh`.
  Themes can now ship `tmux.conf`; when present, `thpm` installs it as
  `~/.config/tmux/omarchy-theme.conf`, ensures the user's tmux config sources
  that stable file once, and reloads running tmux sessions.

### Fixed

- Removed stale tmux theme state when switching to a theme that does not ship
  `tmux.conf`. The tmux plugin now removes its managed source line and copied
  theme file before reloading the user's tmux config.
