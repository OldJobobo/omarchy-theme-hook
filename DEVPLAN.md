# DEVPLAN: Plugin Framework for Omarchy Theme Hook

## Context and current state (review)
- The entrypoint is `theme-set`, which reads `~/.config/omarchy/current/theme/alacritty.toml`, exports color variables, and executes executable scripts from `~/.config/omarchy/hooks/theme-set.d/` in glob order.
- Hook scripts are standalone bash files that either:
  - generate a derived theme file under `~/.config/omarchy/current/theme/`, and/or
  - copy/link into each app’s config, and/or
  - apply changes directly (e.g., `gsettings`, `spicetify`, `vicinae theme set`).
- Ordering is implicit via filename prefixes (00/10/20/etc) and glob order; there is no metadata or dependency management.
- There is no standardized plugin packaging format, enable/disable mechanism, or install workflow beyond copying scripts into `theme-set.d`.
- Runtime context is implicit (color variables, `require_restart`, `success`/`warning` helpers) and not formally documented for third-party authors.

## Goals
- Provide a stable, documented plugin interface so third parties can implement new hooks without editing core scripts.
- Support structured metadata (name, description, version, hook targets, requirements, ordering/priority).
- Allow easy enable/disable and safe discovery of plugins.
- Preserve current behavior for existing `theme-set.d/*.sh` hooks during migration.

## Non-goals
- Rewriting every existing hook immediately.
- Introducing a heavy dependency stack (avoid jq/yq requirement for baseline usage).
- Changing the external Omarchy hook contract (keep `theme-set` as the hook entrypoint).

## Proposed architecture

### 1) Plugin layout and manifest
Use a simple, bash-parsable manifest to avoid external dependencies.

**Layout (installed plugin):**
```
plugins/
  <plugin-id>/
    plugin.env
    hooks/
      theme-set.sh
    assets/ (optional)
    README.md (optional)
```

**`plugin.env` format (sourced by bash):**
```
PLUGIN_ID="waybar"
PLUGIN_NAME="Waybar"
PLUGIN_VERSION="0.1.0"
PLUGIN_HOOKS="theme-set"
PLUGIN_PRIORITY="10"
PLUGIN_REQUIRES="waybar,omarchy-restart-waybar"
```

Notes:
- `PLUGIN_HOOKS` can be a comma-separated list to allow future hooks (e.g., `theme-set,theme-unset`).
- `PLUGIN_PRIORITY` replaces filename prefixes; lower runs first.
- `PLUGIN_REQUIRES` lists commands to check before running.

### 2) Discovery and enable/disable
- Plugins live under `~/.config/omarchy/hooks/plugins/` (user space) and optionally a system dir like `/usr/share/omarchy/hooks/plugins/`.
- Enablement via a lightweight registry:
  - `~/.config/omarchy/hooks/plugins.enabled` containing one `PLUGIN_ID` per line, OR
  - `plugins/enabled.d/<plugin-id>` as a symlink to the plugin directory.
- If no registry is present, treat all discovered plugins as enabled (opt-out model). This is the preferred default.

### 3) Runtime contract
`theme-set` should export a stable environment for plugins:
- Theme context:
  - `OMARCHY_THEME_NAME`, `OMARCHY_THEME_DIR`, `OMARCHY_CURRENT_THEME_DIR`
- Color exports (existing):
  - `primary_background`, `primary_foreground`, `normal_*`, `bright_*`, and `rgb_*`
- Helpers:
  - `success`, `warning`, `error`, `skipped`, `require_restart`

### 4) Execution model
- `theme-set` becomes a dispatcher:
  1. Load colors and helpers as it does now.
  2. Load all plugin manifests.
  3. Filter enabled plugins.
  4. Check `PLUGIN_REQUIRES` before executing.
  5. Execute `hooks/theme-set.sh` for each plugin in priority order.
  6. Preserve current restart aggregation behavior.
- Backward compatibility: if `theme-set.d/*.sh` exists, run those too (or provide a migration shim).
- Plugins run in the shared shell environment for speed; avoid subshell isolation unless needed later.

### 5) Developer experience
- Provide a template plugin in `templates/plugin/` with a minimal manifest and a `theme-set.sh` skeleton.
- Add docs in `README.md` or `docs/PLUGINS.md` showing:
  - How to create a plugin directory.
  - How to declare requirements.
  - How to reference the exported color variables.
  - How to request restarts.

## Implementation phases

### Phase 0: Baseline documentation
- Add `DEVPLAN.md` (this file).
- Add `docs/PLUGINS.md` with a concise authoring guide and a minimal example.

### Phase 1: Plugin runtime foundation
- Add a small library (e.g., `lib/plugin-runtime.sh`) to:
  - Discover plugin dirs.
  - Source `plugin.env` safely.
  - Sort by `PLUGIN_PRIORITY`.
  - Check `PLUGIN_REQUIRES` and skip with a clear message.
- Update `theme-set` to:
  - Source the runtime library.
  - Execute plugins for the `theme-set` hook.
  - Keep the existing `theme-set.d` execution path for compatibility.

### Phase 2: Migration path
- Provide a script (optional) to convert an existing `theme-set.d/*.sh` file into a plugin stub.
- Migrate 1–2 core hooks as examples (e.g., Waybar and GTK) to validate the framework.

### Phase 3: Polishing and stability
- Add structured logging to `~/.cache/omarchy/theme-hook.log` with plugin IDs and timestamps.
- Validate required theme files (e.g., missing `alacritty.toml`) and fail gracefully.
- Add `theme-hook list` and `theme-hook enable/disable` helper commands (optional).

## Open questions
- Should plugin manifests be allowed to declare "provides" outputs (e.g., `waybar.css`) to avoid conflicts?

## Minimal example plugin
```
plugins/example/plugin.env
plugins/example/hooks/theme-set.sh
```

`plugin.env`:
```
PLUGIN_ID="example"
PLUGIN_NAME="Example"
PLUGIN_VERSION="0.1.0"
PLUGIN_HOOKS="theme-set"
PLUGIN_PRIORITY="50"
PLUGIN_REQUIRES=""
```

`hooks/theme-set.sh`:
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
