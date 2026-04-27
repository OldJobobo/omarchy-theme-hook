#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
TEST_FAILURES=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1"
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$expected" == "$actual" ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  expected: %q\n' "$expected"
    printf '  actual:   %q\n' "$actual"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  missing: %q\n' "$needle"
    printf '  output:  %s\n' "$haystack"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"

  if [[ -f "$file" ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  missing file: %s\n' "$file"
  fi
}

assert_file_missing() {
  local file="$1"
  local message="$2"

  if [[ ! -e "$file" ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  file should not exist: %s\n' "$file"
  fi
}

assert_file_executable() {
  local file="$1"
  local message="$2"

  if [[ -x "$file" ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  file is not executable: %s\n' "$file"
  fi
}

assert_file_not_executable() {
  local file="$1"
  local message="$2"

  if [[ -f "$file" && ! -x "$file" ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  file is executable or missing: %s\n' "$file"
  fi
}

write_colors_fixture() {
  local home_dir="$1"
  local theme_dir="$home_dir/.config/omarchy/current/theme"

  mkdir -p "$theme_dir"
  cat > "$theme_dir/colors.toml" <<'EOF'
background = "#101112"
foreground = "#f1f2f3"
cursor = "#abcdef"
selection_background = "#222222"
selection_foreground = "#eeeeee"
color0 = "#000000"
color1 = "#111111"
color2 = "#222222"
color3 = "#333333"
color4 = "#444444"
color5 = "#555555"
color6 = "#666666"
color7 = "#777777"
color8 = "#888888"
color9 = "#999999"
color10 = "#aaaaaa"
color11 = "#bbbbbb"
color12 = "#cccccc"
color13 = "#dddddd"
color14 = "#eeeeee"
color15 = "#ffffff"
EOF
}

make_stub_bin() {
  local bin_dir="$1"
  local name="$2"
  local body="$3"

  cat > "$bin_dir/$name" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$bin_dir/$name"
}

run_thpm() {
  local home_dir="$1"
  shift
  HOME="$home_dir" "$ROOT_DIR/thpm" "$@" 2>&1
}

run_thpm_with_path() {
  local home_dir="$1"
  local bin_dir="$2"
  shift 2
  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/thpm" "$@" 2>&1
}

test_shell_syntax() {
  local script
  local failed=0

  for script in "$ROOT_DIR/thpm" "$ROOT_DIR/theme-set" "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" "$ROOT_DIR"/theme-set.d/*.sh; do
    if ! bash -n "$script"; then
      failed=1
    fi
  done

  assert_eq "0" "$failed" "all shell scripts pass bash -n"
}

test_thpm_help() {
  local home_dir="$TMP_ROOT/help-home"
  local output

  mkdir -p "$home_dir"
  output="$(run_thpm "$home_dir" help)"

  assert_contains "$output" "Usage: thpm [command] [plugin]" "thpm help prints usage"
  assert_contains "$output" "enable" "thpm help lists enable command"
  assert_contains "$output" "disable" "thpm help lists disable command"
}

test_thpm_enable_disable_and_list() {
  local home_dir="$TMP_ROOT/thpm-home"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output

  mkdir -p "$hook_dir"
  printf '#!/usr/bin/env bash\n' > "$hook_dir/10-fzf.sh"
  chmod -x "$hook_dir/10-fzf.sh"

  output="$(run_thpm "$home_dir" list)"
  assert_contains "$output" "Disabled Plugins:" "thpm list shows disabled section"
  assert_contains "$output" "fzf" "thpm list includes disabled plugin name"

  output="$(run_thpm "$home_dir" enable fzf)"
  assert_contains "$output" "Plugin Enabled: fzf" "thpm enable reports enabled plugin"
  assert_file_executable "$hook_dir/10-fzf.sh" "thpm enable marks plugin executable"

  output="$(run_thpm "$home_dir" disable fzf)"
  assert_contains "$output" "Plugin Disabled: fzf" "thpm disable reports disabled plugin"
  assert_file_not_executable "$hook_dir/10-fzf.sh" "thpm disable removes executable bit"

  output="$(run_thpm "$home_dir" enable missing-plugin)"
  assert_contains "$output" "Plugin not found: missing-plugin" "thpm enable reports missing plugin"
}

test_thpm_aliases() {
  local home_dir="$TMP_ROOT/alias-home"
  local bin_dir="$TMP_ROOT/alias-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output

  mkdir -p "$hook_dir" "$bin_dir"
  printf '#!/usr/bin/env bash\n' > "$hook_dir/10-fzf.sh"
  chmod -x "$hook_dir/10-fzf.sh"
  make_stub_bin "$bin_dir" omarchy-hook 'printf "omarchy-hook %s\n" "$*"'
  make_stub_bin "$bin_dir" curl 'printf "curl %s\n" "$*"'

  output="$(run_thpm "$home_dir" l)"
  assert_contains "$output" "Disabled Plugins:" "thpm l aliases list"

  output="$(run_thpm "$home_dir" e fzf)"
  assert_contains "$output" "Plugin Enabled: fzf" "thpm e aliases enable"

  output="$(run_thpm "$home_dir" d fzf)"
  assert_contains "$output" "Plugin Disabled: fzf" "thpm d aliases disable"

  output="$(run_thpm_with_path "$home_dir" "$bin_dir" r)"
  assert_contains "$output" "omarchy-hook theme-set" "thpm r aliases run"

  output="$(run_thpm_with_path "$home_dir" "$bin_dir" up)"
  assert_contains "$output" "raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/install.sh" "thpm up aliases update"

  output="$(run_thpm_with_path "$home_dir" "$bin_dir" rm)"
  assert_contains "$output" "raw.githubusercontent.com/OldJobobo/theme-hook-plugin-manager/thpm/uninstall.sh" "thpm rm aliases uninstall"
}

test_theme_set_exports_colors_and_runs_enabled_hooks() {
  local home_dir="$TMP_ROOT/theme-set-home"
  local bin_dir="$TMP_ROOT/bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output_file="$TMP_ROOT/hook-output"
  local skipped_file="$TMP_ROOT/skipped-output"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'printf "notify-send should not be called\n" >&2; exit 1'

  cat > "$hook_dir/10-capture.sh" <<EOF
#!/usr/bin/env bash
{
  printf 'primary_background=%s\n' "\$primary_background"
  printf 'primary_foreground=%s\n' "\$primary_foreground"
  printf 'rgb_primary_background=%s\n' "\$rgb_primary_background"
  printf 'normal_red=%s\n' "\$normal_red"
  printf 'bright_white=%s\n' "\$bright_white"
} > "$output_file"
require_restart nonexistent-app
EOF
  chmod +x "$hook_dir/10-capture.sh"

  cat > "$hook_dir/20-disabled.sh" <<EOF
#!/usr/bin/env bash
printf 'disabled hook ran\n' > "$skipped_file"
EOF
  chmod -x "$hook_dir/20-disabled.sh"

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set"

  assert_contains "$(cat "$output_file")" "primary_background=101112" "theme-set exports background color"
  assert_contains "$(cat "$output_file")" "primary_foreground=f1f2f3" "theme-set exports foreground color"
  assert_contains "$(cat "$output_file")" "rgb_primary_background=16, 17, 18" "theme-set exports rgb background"
  assert_contains "$(cat "$output_file")" "normal_red=111111" "theme-set exports normal palette color"
  assert_contains "$(cat "$output_file")" "bright_white=ffffff" "theme-set exports bright palette color"

  if [[ -e "$skipped_file" ]]; then
    fail "theme-set skips non-executable hooks"
  else
    pass "theme-set skips non-executable hooks"
  fi
}

test_theme_set_errors_without_colors_file() {
  local home_dir="$TMP_ROOT/missing-colors-home"
  local output
  local status

  mkdir -p "$home_dir"
  set +e
  output="$(HOME="$home_dir" "$ROOT_DIR/theme-set" 2>&1)"
  status=$?
  set +e

  assert_eq "1" "$status" "theme-set exits non-zero without colors.toml"
  assert_contains "$output" "colors.toml not found" "theme-set explains missing colors.toml"
}

test_theme_set_reports_hook_failure() {
  local home_dir="$TMP_ROOT/failing-hook-home"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output
  local status

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir"
  cat > "$hook_dir/10-fail.sh" <<'EOF'
#!/usr/bin/env bash
exit 42
EOF
  chmod +x "$hook_dir/10-fail.sh"

  set +e
  output="$(HOME="$home_dir" "$ROOT_DIR/theme-set" 2>&1)"
  status=$?
  set +e

  assert_eq "1" "$status" "theme-set exits non-zero when an enabled hook fails"
  assert_contains "$output" "Hook 10-fail.sh failed" "theme-set names failed hook"
}

test_theme_set_sends_restart_notification() {
  local home_dir="$TMP_ROOT/restart-home"
  local bin_dir="$TMP_ROOT/restart-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local notify_log="$TMP_ROOT/notify.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  make_stub_bin "$bin_dir" pgrep '[[ "$2" == "sampleapp" ]]'
  cat > "$bin_dir/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$notify_log"
EOF
  chmod +x "$bin_dir/notify-send"

  cat > "$hook_dir/10-restart.sh" <<'EOF'
#!/usr/bin/env bash
require_restart sampleapp
EOF
  chmod +x "$hook_dir/10-restart.sh"

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set"

  assert_file_exists "$notify_log" "theme-set sends notification for running restart target"
  assert_contains "$(cat "$notify_log")" "Theme Hook Plugin Manager" "restart notification has title"
  assert_contains "$(cat "$notify_log")" "Sampleapp" "restart notification lists running app"
}

test_qutebrowser_plugin_writes_theme_and_config() {
  local home_dir="$TMP_ROOT/qutebrowser-home"
  local bin_dir="$TMP_ROOT/qutebrowser-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local draw_file="$home_dir/.config/qutebrowser/omarchy/draw.py"
  local config_file="$home_dir/.config/qutebrowser/config.py"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/40-qutebrowser.sh" "$hook_dir/40-qutebrowser.sh"
  chmod +x "$hook_dir/40-qutebrowser.sh"
  make_stub_bin "$bin_dir" qutebrowser 'exit 0'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set"

  assert_file_exists "$draw_file" "qutebrowser plugin writes draw.py"
  assert_contains "$(cat "$draw_file")" "bg        = '#101112'" "qutebrowser draw.py uses background"
  assert_contains "$(cat "$draw_file")" "preferred_color_scheme = 'dark'" "qutebrowser draw.py defaults to dark mode"
  assert_file_exists "$config_file" "qutebrowser plugin writes config.py"
  assert_contains "$(cat "$config_file")" "import omarchy.draw" "qutebrowser config imports theme"
  assert_contains "$(cat "$config_file")" "omarchy.draw.apply(c)" "qutebrowser config applies theme"
}

test_install_preserves_disabled_plugins_and_installs_files() {
  local home_dir="$TMP_ROOT/install-home"
  local bin_dir="$TMP_ROOT/install-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local installed_thpm="$home_dir/.local/share/omarchy/bin/thpm"
  local installed_theme_set="$home_dir/.config/omarchy/hooks/theme-set"
  local output

  mkdir -p "$hook_dir" "$bin_dir" "$home_dir/.local/share/omarchy/bin"
  printf '#!/usr/bin/env bash\n' > "$hook_dir/00-fish.sh"
  chmod -x "$hook_dir/00-fish.sh"

  make_stub_bin "$bin_dir" pacman 'exit 0'
  make_stub_bin "$bin_dir" sudo 'printf "sudo should not be called\n" >&2; exit 1'
  make_stub_bin "$bin_dir" omarchy-hook 'printf "omarchy-hook %s\n" "$*"'
  make_stub_bin "$bin_dir" omarchy-show-done 'printf "done\n"'
  cat > "$bin_dir/git" <<EOF
#!/usr/bin/env bash
mkdir -p /tmp/theme-hook
cp "$ROOT_DIR/thpm" /tmp/theme-hook/thpm
cp "$ROOT_DIR/theme-set" /tmp/theme-hook/theme-set
mkdir -p /tmp/theme-hook/theme-set.d
cp "$ROOT_DIR"/theme-set.d/*.sh /tmp/theme-hook/theme-set.d/
EOF
  chmod +x "$bin_dir/git"

  output="$(PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/install.sh" 2>&1)"

  assert_contains "$output" "Downloading thpm.." "install announces download"
  assert_contains "$output" "omarchy-hook theme-set" "install applies theme-set hook"
  assert_file_executable "$installed_thpm" "install writes executable thpm"
  assert_file_executable "$installed_theme_set" "install writes executable theme-set hook"
  assert_file_not_executable "$hook_dir/00-fish.sh" "install preserves disabled plugin permission"
  assert_file_executable "$hook_dir/30-vscode.sh" "install enables bundled plugins by default"
}

test_uninstall_removes_files_and_qutebrowser_theme() {
  local home_dir="$TMP_ROOT/uninstall-home"
  local bin_dir="$TMP_ROOT/uninstall-bin"
  local output

  mkdir -p "$bin_dir" "$home_dir/.local/share/omarchy/bin" "$home_dir/.config/omarchy/hooks/theme-set.d" "$home_dir/.config/qutebrowser/omarchy"
  printf '#!/usr/bin/env bash\n' > "$home_dir/.local/share/omarchy/bin/thpm"
  printf '#!/usr/bin/env bash\n' > "$home_dir/.config/omarchy/hooks/theme-set"
  printf '#!/usr/bin/env bash\n' > "$home_dir/.config/omarchy/hooks/theme-set.d/10-fzf.sh"
  cat > "$home_dir/.config/qutebrowser/config.py" <<'EOF'
config.load_autoconfig()
import omarchy.draw
omarchy.draw.apply(c)
EOF

  make_stub_bin "$bin_dir" omarchy-show-logo 'printf "logo\n"'
  make_stub_bin "$bin_dir" omarchy-show-done 'printf "done\n"'
  make_stub_bin "$bin_dir" python 'exit 1'
  make_stub_bin "$bin_dir" spicetify 'exit 1'
  make_stub_bin "$bin_dir" gsettings 'exit 1'
  make_stub_bin "$bin_dir" qutebrowser 'exit 0'
  make_stub_bin "$bin_dir" vicinae 'exit 1'

  output="$(PATH="$bin_dir:$PATH" HOME="$home_dir" bash "$ROOT_DIR/uninstall.sh" 2>&1)"

  assert_contains "$output" "Uninstalled thpm!" "uninstall reports completion"
  assert_file_missing "$home_dir/.local/share/omarchy/bin/thpm" "uninstall removes thpm binary"
  assert_file_missing "$home_dir/.config/omarchy/hooks/theme-set" "uninstall removes theme-set hook"
  assert_file_missing "$home_dir/.config/omarchy/hooks/theme-set.d" "uninstall removes plugin directory"
  assert_file_missing "$home_dir/.config/qutebrowser/omarchy" "uninstall removes qutebrowser theme directory"
  assert_eq "config.load_autoconfig()" "$(cat "$home_dir/.config/qutebrowser/config.py")" "uninstall removes qutebrowser config lines"
}

main() {
  test_shell_syntax
  test_thpm_help
  test_thpm_enable_disable_and_list
  test_thpm_aliases
  test_theme_set_exports_colors_and_runs_enabled_hooks
  test_theme_set_errors_without_colors_file
  test_theme_set_reports_hook_failure
  test_theme_set_sends_restart_notification
  test_qutebrowser_plugin_writes_theme_and_config
  test_install_preserves_disabled_plugins_and_installs_files
  test_uninstall_removes_files_and_qutebrowser_theme

  if [[ "$TEST_FAILURES" -gt 0 ]]; then
    printf '\n%d test(s) failed.\n' "$TEST_FAILURES"
    exit 1
  fi

  printf '\nAll tests passed.\n'
}

main "$@"
