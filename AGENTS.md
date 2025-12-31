# Repository Guidelines

## Project Structure & Module Organization
- `theme-set` is the entrypoint hook. It reads `~/.config/omarchy/current/theme/alacritty.toml`, exports color variables, and runs executable scripts.
- `theme-set.d/` holds per-app hook scripts (`*.sh`). Ordering is by filename prefix (e.g., `00-`, `10-`, `20-`).
- `assets/` stores repo media like the preview image.
- `install.sh` and `uninstall.sh` manage install/remove workflows for Omarchy.
- `DEVPLAN.md` documents the planned plugin framework; treat it as design context.

## Build, Test, and Development Commands
- `bash install.sh` installs the hook into an Omarchy setup (requires Omarchy tooling and system deps).
- `theme-hook-update` updates an installed hook (created by the installer).
- `omarchy-hook theme-set` runs the hook after installation.
- Local dev quick check: `bash theme-set` (requires a valid `~/.config/omarchy/current/theme/alacritty.toml`).

## Coding Style & Naming Conventions
- Language: Bash. Prefer POSIX-ish shell where possible, but Bash is fine.
- Indentation: 4 spaces in scripts (match `theme-set`).
- New hooks go in `theme-set.d/` with numeric prefixes to control order, e.g., `10-<app>.sh`.
- Scripts must be executable and keep side effects explicit (file paths, app restarts).

## Testing Guidelines
- No automated tests currently.
- Manual validation: run `omarchy-hook theme-set`, confirm generated theme files under `~/.config/omarchy/current/theme/`, and verify the target app picks up the theme.
- If you add a new hook, note any prerequisites (packages, config flags) in the PR.

## Commit & Pull Request Guidelines
- Commit messages are short, plain-English summaries (e.g., "Add Waybar theme directory support").
- PRs should include: a brief description, affected apps/scripts, manual test steps, and any new dependencies.

## Configuration Notes
- The hook expects Omarchy’s theme files and directories in `~/.config/omarchy/`.
- Some apps require manual theme selection or enabling legacy CSS; mention this when relevant.
