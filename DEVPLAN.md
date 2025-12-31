# DEVPLAN: Plugin Extensions for Omarchy Theme Hook

## Context and current state (review)
- The entrypoint is `theme-set`, which reads `~/.config/omarchy/current/theme/alacritty.toml`, exports color variables, and executes executable scripts from `~/.config/omarchy/hooks/theme-set.d/` in glob order.
- Hook scripts are standalone bash files that either:
  - generate a derived theme file under `~/.config/omarchy/current/theme/`, and/or
  - copy/link into each app’s config, and/or
  - apply changes directly (e.g., `gsettings`, `spicetify`, `vicinae theme set`).
- Ordering is implicit via filename prefixes (00/10/20/etc) and glob order.
- Runtime context is implicit (color variables, `require_restart`, `success`/`warning` helpers).

## Goals
- Keep things simple: plugins are just optional extensions to the existing hook.
- Allow drop-in plugin scripts to run when `theme-set` fires, without reworking the core hook logic.
- Preserve current behavior for existing `theme-set.d/*.sh` hooks.

## Non-goals
- Rewriting existing hooks into a new framework.
- Adding manifests, metadata, or dependency resolution.
- Changing the external Omarchy hook contract (`theme-set` stays the entrypoint).

## Proposed architecture (simple plugin extensions)

### 1) Plugin layout
Plugins are just executable scripts. If a plugin script exists, `theme-set` runs it before continuing the normal flow.

**Layout (installed plugin):**
```
plugins/
  theme-set.d/
    <plugin-name>.sh
```

Example plugin name: `10-waybar-theme-dir.sh`

Ordering remains filename prefix + glob order, consistent with `theme-set.d`.

### 2) Discovery and execution model
- Plugins live under `~/.config/omarchy/hooks/plugins/theme-set.d/`.
- When `theme-set` runs:
  1. Load colors and helper functions (current behavior).
  2. Execute any executable plugin scripts in `plugins/theme-set.d/`.
  3. Execute existing hooks in `theme-set.d/`.
  4. Aggregate restarts (current behavior).

### 3) Runtime contract
Plugins run in the same shell environment as the hook scripts and can use:
- Theme context:
  - `OMARCHY_THEME_NAME`, `OMARCHY_THEME_DIR`, `OMARCHY_CURRENT_THEME_DIR`
- Color exports (existing):
  - `primary_background`, `primary_foreground`, `normal_*`, `bright_*`, and `rgb_*`
- Helpers:
  - `success`, `warning`, `error`, `skipped`, `require_restart`

### 4) Backward compatibility
The existing `theme-set.d/*.sh` execution stays unchanged. Plugins are additive and run first.

### 5) Developer experience
- Add a short section in `README.md` (or `docs/PLUGINS.md`) showing the plugin folder path and a minimal example.

## Implementation phases

### Phase 0: Baseline documentation
- Add `DEVPLAN.md` (this file).
- Add `docs/PLUGINS.md` (optional) with a concise authoring guide and a minimal example.

### Phase 1: Plugin runtime foundation
- Update `theme-set` to:
  - Execute any scripts in `~/.config/omarchy/hooks/plugins/theme-set.d/` (if present).
  - Then execute the existing `theme-set.d` scripts as today.

### Phase 2: Migration path
- Migrate 1–2 enhancements as plugins (e.g., Waybar theme directory handling).

### Phase 3: Polishing and stability
- Add structured logging to `~/.cache/omarchy/theme-hook.log` with plugin IDs and timestamps.
- Validate required theme files (e.g., missing `alacritty.toml`) and fail gracefully.
- Add `theme-hook list` and `theme-hook enable/disable` helper commands (optional).

## Open questions
- Do we want a simple enable/disable toggle (e.g., a `plugins.disabled.d/` folder), or is presence in the plugin folder enough?

## Minimal example plugin
```
plugins/theme-set.d/10-example.sh
```

`10-example.sh`:
```
#!/bin/bash
# Uses exported colors from theme-set
output_file="$HOME/.config/omarchy/current/theme/example.txt"
cat > "$output_file" <<EOF
primary_background=#${primary_background}
primary_foreground=#${primary_foreground}
EOF
success "Example plugin updated!"
```
