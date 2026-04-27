#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
TEST_FAILURES=0
TEST_ASSERTIONS=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1"
  TEST_ASSERTIONS=$((TEST_ASSERTIONS + 1))
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
  TEST_ASSERTIONS=$((TEST_ASSERTIONS + 1))
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$message"
  else
    fail "$message"
    printf '  unexpected: %q\n' "$needle"
    printf '  output:     %s\n' "$haystack"
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

make_install_git_stub() {
  local bin_dir="$1"

  cat > "$bin_dir/git" <<EOF
#!/usr/bin/env bash
mkdir -p /tmp/theme-hook
cp "$ROOT_DIR/thpm" /tmp/theme-hook/thpm
cp "$ROOT_DIR/theme-set" /tmp/theme-hook/theme-set
mkdir -p /tmp/theme-hook/theme-set.d
cp "$ROOT_DIR"/theme-set.d/*.sh /tmp/theme-hook/theme-set.d/
EOF
  chmod +x "$bin_dir/git"
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

test_thpm_open_uses_xdg_open_for_hook_dir() {
  local home_dir="$TMP_ROOT/open-home"
  local bin_dir="$TMP_ROOT/open-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local open_log="$TMP_ROOT/xdg-open.log"

  mkdir -p "$hook_dir" "$bin_dir"
  cat > "$bin_dir/xdg-open" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$open_log"
EOF
  chmod +x "$bin_dir/xdg-open"

  run_thpm_with_path "$home_dir" "$bin_dir" open >/dev/null
  for _ in $(seq 1 20); do
    [[ -f "$open_log" ]] && break
    sleep 0.05
  done

  assert_file_exists "$open_log" "thpm open calls xdg-open when hook directory exists"
  assert_eq "$hook_dir" "$(cat "$open_log")" "thpm open passes hook directory to xdg-open"
}

test_thpm_gtk_post_enable_disable_updates_gsettings() {
  local home_dir="$TMP_ROOT/gtk-home"
  local bin_dir="$TMP_ROOT/gtk-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local gsettings_log="$TMP_ROOT/gsettings.log"

  mkdir -p "$hook_dir" "$bin_dir" "$home_dir/.config/omarchy/current/theme"
  printf '#!/usr/bin/env bash\n' > "$hook_dir/10-gtk.sh"
  chmod -x "$hook_dir/10-gtk.sh"
  cat > "$bin_dir/gsettings" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$gsettings_log"
EOF
  chmod +x "$bin_dir/gsettings"

  run_thpm_with_path "$home_dir" "$bin_dir" enable gtk >/dev/null
  run_thpm_with_path "$home_dir" "$bin_dir" disable gtk >/dev/null

  assert_contains "$(cat "$gsettings_log")" "set org.gnome.desktop.interface gtk-theme adw-gtk3-tmp-dark" "gtk enable sets temporary dark theme"
  assert_contains "$(cat "$gsettings_log")" "set org.gnome.desktop.interface gtk-theme adw-gtk3-dark" "gtk enable sets dark theme"
  assert_contains "$(cat "$gsettings_log")" "set org.gnome.desktop.interface gtk-theme Adwaita-dark" "gtk disable restores dark theme"
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

test_qutebrowser_light_mode_change_requires_restart() {
  local home_dir="$TMP_ROOT/qutebrowser-light-home"
  local bin_dir="$TMP_ROOT/qutebrowser-light-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local draw_file="$home_dir/.config/qutebrowser/omarchy/draw.py"
  local notify_log="$TMP_ROOT/qutebrowser-light-notify.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$(dirname "$draw_file")"
  touch "$home_dir/.config/omarchy/current/theme/light.mode"
  cat > "$draw_file" <<'EOF'
def apply(c):
    c.colors.webpage.preferred_color_scheme = 'dark'
EOF
  cp "$ROOT_DIR/theme-set.d/40-qutebrowser.sh" "$hook_dir/40-qutebrowser.sh"
  chmod +x "$hook_dir/40-qutebrowser.sh"
  make_stub_bin "$bin_dir" qutebrowser 'exit 0'
  make_stub_bin "$bin_dir" pgrep '[[ "$2" == "qutebrowser" ]]'
  cat > "$bin_dir/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$notify_log"
EOF
  chmod +x "$bin_dir/notify-send"

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set"

  assert_contains "$(cat "$draw_file")" "preferred_color_scheme = 'light'" "qutebrowser switches draw.py to light mode"
  assert_file_exists "$notify_log" "qutebrowser mode change requests restart notification"
  assert_contains "$(cat "$notify_log")" "Qutebrowser" "qutebrowser restart notification lists app"
}

test_fzf_plugin_writes_fish_theme() {
  local home_dir="$TMP_ROOT/fzf-home"
  local bin_dir="$TMP_ROOT/fzf-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output_file="$home_dir/.config/omarchy/current/theme/fzf.fish"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/00-fzf.sh" "$hook_dir/00-fzf.sh"
  chmod +x "$hook_dir/00-fzf.sh"
  make_stub_bin "$bin_dir" fish 'exit 0'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$output_file" "fzf plugin writes fzf.fish"
  assert_contains "$(cat "$output_file")" "set -l color00 '#000000'" "fzf plugin writes normal black"
  assert_contains "$(cat "$output_file")" "set -l color0F '#ffffff'" "fzf plugin writes bright white"
  assert_contains "$(cat "$output_file")" "--color=bg+:\$color00" "fzf plugin writes FZF color options"
}

test_fish_plugin_writes_shell_colors() {
  local home_dir="$TMP_ROOT/fish-home"
  local bin_dir="$TMP_ROOT/fish-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output_file="$home_dir/.config/omarchy/current/theme/colors.fish"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/00-fish.sh" "$hook_dir/00-fish.sh"
  chmod +x "$hook_dir/00-fish.sh"
  make_stub_bin "$bin_dir" fish 'exit 0'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$output_file" "fish plugin writes colors.fish"
  assert_contains "$(cat "$output_file")" "set -U background '#101112'" "fish plugin writes background"
  assert_contains "$(cat "$output_file")" "set -U foreground '#f1f2f3'" "fish plugin writes foreground"
  assert_contains "$(cat "$output_file")" "set -U color15 '#ffffff'" "fish plugin writes bright white"
}

test_foot_plugin_respects_disable_flag() {
  local home_dir="$TMP_ROOT/foot-disabled-home"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local log_file="/tmp/foot-theme-hook.log"

  rm -f "$log_file"
  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir"
  cp "$ROOT_DIR/theme-set.d/26-foot-live-colors.sh" "$hook_dir/26-foot-live-colors.sh"
  chmod +x "$hook_dir/26-foot-live-colors.sh"

  FOOT_LIVE_THEME=0 HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$log_file" "foot plugin writes log when disabled"
  assert_contains "$(cat "$log_file")" "disabled via FOOT_LIVE_THEME=0" "foot plugin respects disable flag"
}

test_foot_plugin_logs_missing_theme_file() {
  local home_dir="$TMP_ROOT/foot-missing-home"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local log_file="/tmp/foot-theme-hook.log"

  rm -f "$log_file"
  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir"
  cp "$ROOT_DIR/theme-set.d/26-foot-live-colors.sh" "$hook_dir/26-foot-live-colors.sh"
  chmod +x "$hook_dir/26-foot-live-colors.sh"

  HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$log_file" "foot plugin writes log when foot.ini is missing"
  assert_contains "$(cat "$log_file")" "missing theme file:" "foot plugin logs missing foot.ini"
}

test_foot_plugin_reads_theme_and_logs_no_ttys() {
  local home_dir="$TMP_ROOT/foot-theme-home"
  local bin_dir="$TMP_ROOT/foot-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local foot_file="$home_dir/.config/omarchy/current/theme/foot.ini"
  local base_file="$home_dir/.config/foot/foot.ini"
  local log_file="/tmp/foot-theme-hook.log"

  rm -f "$log_file"
  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$(dirname "$base_file")"
  cp "$ROOT_DIR/theme-set.d/26-foot-live-colors.sh" "$hook_dir/26-foot-live-colors.sh"
  chmod +x "$hook_dir/26-foot-live-colors.sh"
  cat > "$foot_file" <<'EOF'
[colors]
background = 202122
foreground = e1e2e3
cursor = c0ffee
selection-background = 303132
selection-foreground = fafafa
regular0 = 000001
bright7 = fffffe
EOF
  cat > "$base_file" <<'EOF'
[colors]
alpha = 0.75
EOF
  make_stub_bin "$bin_dir" ps 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$log_file" "foot plugin logs when no foot tty is available"
  assert_contains "$(cat "$log_file")" "no foot tty updates applied (attempted=0)" "foot plugin handles no writable foot tty"
}

test_foot_plugin_writes_osc_sequences_to_tty() {
  local home_dir="$TMP_ROOT/foot-tty-home"
  local bin_dir="$TMP_ROOT/foot-tty-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local foot_file="$home_dir/.config/omarchy/current/theme/foot.ini"
  local wrapper="$TMP_ROOT/foot-tty-wrapper.sh"
  local output

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/26-foot-live-colors.sh" "$hook_dir/26-foot-live-colors.sh"
  chmod +x "$hook_dir/26-foot-live-colors.sh"
  cat > "$foot_file" <<'EOF'
[colors]
background = 202122
foreground = e1e2e3
cursor = c0ffee
selection-background = 303132
selection-foreground = fafafa
regular0 = 000001
regular1 = 111112
regular2 = 222223
regular3 = 333334
regular4 = 444445
regular5 = 555556
regular6 = 666667
regular7 = 777778
bright0 = 888889
bright1 = 99999a
bright2 = aaaabb
bright3 = bbbbcc
bright4 = ccccdd
bright5 = ddddee
bright6 = eeeeff
bright7 = fffffe
EOF

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -u
tty_name="\$(tty)"
tty_name="\${tty_name#/dev/}"
cat > "$bin_dir/ps" <<PS
#!/usr/bin/env bash
printf '100 0 %s foot\n' "\$tty_name"
PS
chmod +x "$bin_dir/ps"
PATH="$bin_dir:\$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set"
EOF
  chmod +x "$wrapper"

  if ! command -v script >/dev/null 2>&1; then
    fail "foot plugin writes OSC sequences to a writable tty"
    printf '  missing command: script\n'
    return
  fi

  output="$(script -qfec "$wrapper" /dev/null 2>&1)"

  assert_contains "$output" $'\e]10;rgb:f1/f2/f3\e\\' "foot plugin writes foreground OSC sequence"
  assert_contains "$output" $'\e]11;rgb:10/11/12\e\\' "foot plugin writes background OSC sequence"
  assert_contains "$output" $'\e]4;15;rgb:ff/ff/ff\e\\' "foot plugin writes palette OSC sequence"
}

test_cava_plugin_writes_theme_and_updates_config() {
  local home_dir="$TMP_ROOT/cava-home"
  local bin_dir="$TMP_ROOT/cava-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local theme_file="$home_dir/.config/cava/themes/omarchy"
  local config_file="$home_dir/.config/cava/config"
  local pkill_log="$TMP_ROOT/pkill.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$(dirname "$config_file")"
  cp "$ROOT_DIR/theme-set.d/40-cava.sh" "$hook_dir/40-cava.sh"
  chmod +x "$hook_dir/40-cava.sh"
  cat > "$config_file" <<'EOF'
[general]
framerate = 60

[color]
gradient = 0
EOF
  make_stub_bin "$bin_dir" cava 'exit 0'
  make_stub_bin "$bin_dir" pgrep '[[ "$2" == "cava" ]]'
  cat > "$bin_dir/pkill" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$pkill_log"
EOF
  chmod +x "$bin_dir/pkill"
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$theme_file" "cava plugin writes omarchy theme"
  assert_contains "$(cat "$theme_file")" "gradient_color_1 = '#666666'" "cava theme uses normal cyan"
  assert_contains "$(cat "$theme_file")" "gradient_color_8 = '#666666'" "cava theme writes final gradient color"
  assert_contains "$(cat "$config_file")" "theme = 'omarchy'" "cava plugin inserts theme setting"
  assert_file_exists "$pkill_log" "cava plugin signals running cava"
  assert_contains "$(cat "$pkill_log")" "-USR2 cava" "cava plugin sends USR2"
}

test_cava_plugin_does_not_duplicate_theme_setting() {
  local home_dir="$TMP_ROOT/cava-existing-home"
  local bin_dir="$TMP_ROOT/cava-existing-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local config_file="$home_dir/.config/cava/config"
  local theme_count

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$(dirname "$config_file")"
  cp "$ROOT_DIR/theme-set.d/40-cava.sh" "$hook_dir/40-cava.sh"
  chmod +x "$hook_dir/40-cava.sh"
  cat > "$config_file" <<'EOF'
[color]
theme = 'omarchy'
gradient = 0
EOF
  make_stub_bin "$bin_dir" cava 'exit 0'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null
  theme_count="$(grep -c "theme = 'omarchy'" "$config_file")"

  assert_eq "1" "$theme_count" "cava plugin does not duplicate existing theme setting"
}

test_superfile_plugin_writes_theme_and_requests_restart() {
  local home_dir="$TMP_ROOT/superfile-home"
  local bin_dir="$TMP_ROOT/superfile-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local theme_file="$home_dir/.config/superfile/theme/omarchy.toml"
  local notify_log="$TMP_ROOT/superfile-notify.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/10-superfile.sh" "$hook_dir/10-superfile.sh"
  chmod +x "$hook_dir/10-superfile.sh"
  make_stub_bin "$bin_dir" spf 'exit 0'
  make_stub_bin "$bin_dir" pgrep '[[ "$2" == "spf" ]]'
  cat > "$bin_dir/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$notify_log"
EOF
  chmod +x "$bin_dir/notify-send"

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$theme_file" "superfile plugin writes omarchy theme"
  assert_contains "$(cat "$theme_file")" "full_screen_bg = '#101112'" "superfile theme uses background"
  assert_contains "$(cat "$theme_file")" "file_panel_border_active = '#444444'" "superfile theme uses normal blue"
  assert_file_exists "$notify_log" "superfile plugin requests restart notification"
  assert_contains "$(cat "$notify_log")" "Spf" "superfile restart notification lists spf"
}

test_swaync_plugin_installs_theme_files_and_reloads() {
  local home_dir="$TMP_ROOT/swaync-home"
  local bin_dir="$TMP_ROOT/swaync-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local source_dir="$home_dir/.config/omarchy/current/theme"
  local target_dir="$home_dir/.config/swaync"
  local reload_log="$TMP_ROOT/swaync-reload.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/25-swaync.sh" "$hook_dir/25-swaync.sh"
  chmod +x "$hook_dir/25-swaync.sh"
  printf 'style-current\n' > "$source_dir/swaync.style.css"
  printf '{"config":"current"}\n' > "$source_dir/swaync.config.json"
  printf 'colors-current\n' > "$source_dir/colors.css"
  make_stub_bin "$bin_dir" swaync 'exit 0'
  cat > "$bin_dir/swaync-client" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$reload_log"
EOF
  chmod +x "$bin_dir/swaync-client"

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$target_dir/style.css" "swaync plugin installs style.css"
  assert_file_exists "$target_dir/config.json" "swaync plugin installs config.json"
  assert_file_exists "$target_dir/colors.css" "swaync plugin installs colors.css"
  assert_eq "style-current" "$(cat "$target_dir/style.css")" "swaync plugin copies current style"
  assert_contains "$(cat "$reload_log")" "--reload-config -sw" "swaync plugin reloads config"
  assert_contains "$(cat "$reload_log")" "--reload-css -sw" "swaync plugin reloads css"
}

test_swaync_plugin_prefers_named_theme_over_current_theme() {
  local home_dir="$TMP_ROOT/swaync-named-home"
  local bin_dir="$TMP_ROOT/swaync-named-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local current_dir="$home_dir/.config/omarchy/current/theme"
  local named_dir="$home_dir/.config/omarchy/themes/named-theme"
  local target_dir="$home_dir/.config/swaync"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$named_dir"
  cp "$ROOT_DIR/theme-set.d/25-swaync.sh" "$hook_dir/25-swaync.sh"
  chmod +x "$hook_dir/25-swaync.sh"
  printf 'named-theme\n' > "$home_dir/.config/omarchy/current/theme.name"
  printf 'style-current\n' > "$current_dir/swaync.style.css"
  printf '{"config":"current"}\n' > "$current_dir/swaync.config.json"
  printf 'colors-current\n' > "$current_dir/colors.css"
  printf 'style-named\n' > "$named_dir/swaync.style.css"
  printf '{"config":"named"}\n' > "$named_dir/swaync.config.json"
  make_stub_bin "$bin_dir" swaync 'exit 0'
  make_stub_bin "$bin_dir" swaync-client 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_eq "style-named" "$(cat "$target_dir/style.css")" "swaync plugin prefers named theme style"
  assert_eq '{"config":"named"}' "$(cat "$target_dir/config.json")" "swaync plugin prefers named theme config"
  assert_eq "colors-current" "$(cat "$target_dir/colors.css")" "swaync plugin still uses current colors.css"
}

test_vscode_plugin_skips_when_theme_provides_vscode_json() {
  local home_dir="$TMP_ROOT/vscode-skip-home"
  local bin_dir="$TMP_ROOT/vscode-skip-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local generated_file="$home_dir/.config/omarchy/current/theme/vscode_colors.json"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir"
  cp "$ROOT_DIR/theme-set.d/30-vscode.sh" "$hook_dir/30-vscode.sh"
  chmod +x "$hook_dir/30-vscode.sh"
  printf '{"theme":"provided"}\n' > "$home_dir/.config/omarchy/current/theme/vscode.json"
  make_stub_bin "$bin_dir" code 'printf "code should not be called\n" >&2; exit 1'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_missing "$generated_file" "vscode plugin skips generated colors when vscode.json exists"
}

test_vscode_plugin_patches_extension_manifest_and_installs_theme() {
  local home_dir="$TMP_ROOT/vscode-full-home"
  local bin_dir="$TMP_ROOT/vscode-full-bin"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local extension_dir="$home_dir/.vscode/extensions/tintedtheming.base16-tinted-themes-1.0.0"
  local theme_file="$extension_dir/themes/base16/omarchy.json"
  local package_file="$extension_dir/package.json"
  local code_log="$TMP_ROOT/vscode-code.log"

  write_colors_fixture "$home_dir"
  mkdir -p "$hook_dir" "$bin_dir" "$extension_dir/themes/base16"
  cp "$ROOT_DIR/theme-set.d/30-vscode.sh" "$hook_dir/30-vscode.sh"
  chmod +x "$hook_dir/30-vscode.sh"
  cat > "$package_file" <<'EOF'
{
  "contributes": {
    "themes": []
  }
}
EOF
  cat > "$bin_dir/code" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$code_log"
case "\${1:-}" in
  --list-extensions) exit 0 ;;
  --install-extension) exit 0 ;;
esac
EOF
  chmod +x "$bin_dir/code"
  make_stub_bin "$bin_dir" sleep 'exit 0'
  make_stub_bin "$bin_dir" pgrep 'exit 1'
  make_stub_bin "$bin_dir" notify-send 'exit 0'

  PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/theme-set" >/dev/null

  assert_file_exists "$theme_file" "vscode plugin installs omarchy theme file"
  assert_contains "$(cat "$theme_file")" '"name": "Omarchy"' "vscode theme file contains Omarchy theme"
  assert_contains "$(cat "$theme_file")" '"foreground":"#777777"' "vscode theme uses palette colors"
  assert_eq "Omarchy" "$(jq -r '.contributes.themes[] | select(.label == "Omarchy") | .label' "$package_file")" "vscode plugin adds Omarchy manifest entry"
  assert_eq "./themes/base16/omarchy.json" "$(jq -r '.contributes.themes[] | select(.label == "Omarchy") | .path' "$package_file")" "vscode manifest points to installed theme"
  assert_contains "$(cat "$code_log")" "--install-extension tintedtheming.base16-tinted-themes" "vscode plugin installs extension when missing"
}

test_theme_set_extracts_colors_with_leading_whitespace_and_comments() {
  local home_dir="$TMP_ROOT/spaced-colors-home"
  local hook_dir="$home_dir/.config/omarchy/hooks/theme-set.d"
  local output_file="$TMP_ROOT/spaced-colors-output"
  local theme_dir="$home_dir/.config/omarchy/current/theme"

  write_colors_fixture "$home_dir"
  theme_dir="$home_dir/.config/omarchy/current/theme"
  cat > "$theme_dir/colors.toml" <<'EOF'
# comments should be ignored
  background = "#010203" # inline comment
	foreground = "#a0b0c0"
cursor = "#abcdef"
selection_background = "#112233"
selection_foreground = "#ddeeff"
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
  mkdir -p "$hook_dir"
  cat > "$hook_dir/10-capture.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$primary_background|\$primary_foreground|\$rgb_primary_background" > "$output_file"
EOF
  chmod +x "$hook_dir/10-capture.sh"

  HOME="$home_dir" "$ROOT_DIR/theme-set"

  assert_eq "010203|a0b0c0|1, 2, 3" "$(cat "$output_file")" "theme-set extracts colors with whitespace and comments"
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
  make_install_git_stub "$bin_dir"

  output="$(PATH="$bin_dir:$PATH" HOME="$home_dir" "$ROOT_DIR/install.sh" 2>&1)"

  assert_contains "$output" "Downloading thpm.." "install announces download"
  assert_contains "$output" "omarchy-hook theme-set" "install applies theme-set hook"
  assert_file_executable "$installed_thpm" "install writes executable thpm"
  assert_file_executable "$installed_theme_set" "install writes executable theme-set hook"
  assert_file_not_executable "$hook_dir/00-fish.sh" "install preserves disabled plugin permission"
  assert_file_executable "$hook_dir/30-vscode.sh" "install enables bundled plugins by default"
}

test_install_interactive_prompt_installs_missing_adw_theme() {
  local home_dir="$TMP_ROOT/install-interactive-home"
  local bin_dir="$TMP_ROOT/install-interactive-bin"
  local sudo_log="$TMP_ROOT/install-interactive-sudo.log"
  local output

  mkdir -p "$bin_dir" "$home_dir/.local/share/omarchy/bin" "$home_dir/.config/omarchy/hooks"
  make_stub_bin "$bin_dir" pacman 'exit 1'
  cat > "$bin_dir/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$sudo_log"
EOF
  chmod +x "$bin_dir/sudo"
  make_stub_bin "$bin_dir" omarchy-hook 'exit 0'
  make_stub_bin "$bin_dir" omarchy-show-done 'exit 0'
  make_install_git_stub "$bin_dir"

  output="$(printf 'y\n' | PATH="$bin_dir:/bin" HOME="$home_dir" "$ROOT_DIR/install.sh" 2>&1)"

  assert_contains "$output" "\"adw-gtk-theme\" is required to theme GTK applications." "install interactive path explains missing GTK theme"
  assert_file_exists "$sudo_log" "install interactive path invokes sudo when confirmed"
  assert_eq "pacman -S adw-gtk-theme" "$(cat "$sudo_log")" "install interactive path installs adw-gtk-theme"
  assert_file_executable "$home_dir/.local/share/omarchy/bin/thpm" "install interactive path still installs thpm"
}

test_install_gum_prompt_installs_missing_adw_theme() {
  local home_dir="$TMP_ROOT/install-gum-home"
  local bin_dir="$TMP_ROOT/install-gum-bin"
  local sudo_log="$TMP_ROOT/install-gum-sudo.log"
  local gum_log="$TMP_ROOT/install-gum.log"

  mkdir -p "$bin_dir" "$home_dir/.local/share/omarchy/bin" "$home_dir/.config/omarchy/hooks"
  make_stub_bin "$bin_dir" pacman 'exit 1'
  cat > "$bin_dir/gum" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$gum_log"
[[ "\${1:-}" == "confirm" ]] && exit 0
exit 0
EOF
  chmod +x "$bin_dir/gum"
  cat > "$bin_dir/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$sudo_log"
EOF
  chmod +x "$bin_dir/sudo"
  make_stub_bin "$bin_dir" omarchy-hook 'exit 0'
  make_stub_bin "$bin_dir" omarchy-show-done 'exit 0'
  make_install_git_stub "$bin_dir"

  PATH="$bin_dir:/bin" HOME="$home_dir" "$ROOT_DIR/install.sh" >/dev/null 2>&1

  assert_contains "$(cat "$gum_log")" "style --border normal" "install gum path renders warning"
  assert_contains "$(cat "$gum_log")" "confirm Would you like to install \"adw-gtk-theme\"?" "install gum path asks for confirmation"
  assert_eq "pacman -S adw-gtk-theme" "$(cat "$sudo_log")" "install gum path installs adw-gtk-theme"
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

test_uninstall_invokes_external_revert_commands() {
  local home_dir="$TMP_ROOT/uninstall-external-home"
  local bin_dir="$TMP_ROOT/uninstall-external-bin"
  local steam_log="$TMP_ROOT/uninstall-steam.log"
  local spicetify_log="$TMP_ROOT/uninstall-spicetify.log"
  local gsettings_log="$TMP_ROOT/uninstall-gsettings.log"
  local vicinae_log="$TMP_ROOT/uninstall-vicinae.log"

  mkdir -p "$bin_dir" "$home_dir/.local/share/steam-adwaita"
  cat > "$home_dir/.local/share/steam-adwaita/install.py" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$steam_log"
EOF
  chmod +x "$home_dir/.local/share/steam-adwaita/install.py"
  make_stub_bin "$bin_dir" omarchy-show-logo 'exit 0'
  make_stub_bin "$bin_dir" omarchy-show-done 'exit 0'
  make_stub_bin "$bin_dir" python 'exit 0'
  cat > "$bin_dir/spicetify" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$spicetify_log"
EOF
  chmod +x "$bin_dir/spicetify"
  cat > "$bin_dir/gsettings" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$gsettings_log"
EOF
  chmod +x "$bin_dir/gsettings"
  make_stub_bin "$bin_dir" qutebrowser 'exit 1'
  cat > "$bin_dir/vicinae" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$vicinae_log"
EOF
  chmod +x "$bin_dir/vicinae"

  PATH="$bin_dir:$PATH" HOME="$home_dir" bash "$ROOT_DIR/uninstall.sh" >/dev/null 2>&1

  assert_eq "--uninstall" "$(cat "$steam_log")" "uninstall invokes Steam adwaita uninstall"
  assert_eq "restore" "$(cat "$spicetify_log")" "uninstall invokes spicetify restore"
  assert_eq "set org.gnome.desktop.interface gtk-theme Adwaita" "$(cat "$gsettings_log")" "uninstall restores GTK theme"
  assert_eq "theme set vicinae-dark" "$(cat "$vicinae_log")" "uninstall restores Vicinae theme"
}

print_coverage_summary() {
  local all_scripts=("$ROOT_DIR/thpm" "$ROOT_DIR/theme-set" "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh")
  local direct_scripts=(
    "$ROOT_DIR/thpm"
    "$ROOT_DIR/theme-set"
    "$ROOT_DIR/install.sh"
    "$ROOT_DIR/uninstall.sh"
    "$ROOT_DIR/theme-set.d/00-fish.sh"
    "$ROOT_DIR/theme-set.d/00-fzf.sh"
    "$ROOT_DIR/theme-set.d/10-superfile.sh"
    "$ROOT_DIR/theme-set.d/25-swaync.sh"
    "$ROOT_DIR/theme-set.d/26-foot-live-colors.sh"
    "$ROOT_DIR/theme-set.d/30-vscode.sh"
    "$ROOT_DIR/theme-set.d/40-cava.sh"
    "$ROOT_DIR/theme-set.d/40-qutebrowser.sh"
  )
  local script
  local total
  local direct
  local percent

  for script in "$ROOT_DIR"/theme-set.d/*.sh; do
    all_scripts+=("$script")
  done

  total="${#all_scripts[@]}"
  direct="${#direct_scripts[@]}"
  percent=$((direct * 100 / total))

  printf '\nAssertions: %d\n' "$TEST_ASSERTIONS"
  printf 'Direct script coverage: %d/%d scripts (%d%%)\n' "$direct" "$total" "$percent"
  printf 'Note: this is script-level behavioral coverage, not line coverage.\n'
}

main() {
  test_shell_syntax
  test_thpm_help
  test_thpm_enable_disable_and_list
  test_thpm_aliases
  test_thpm_open_uses_xdg_open_for_hook_dir
  test_thpm_gtk_post_enable_disable_updates_gsettings
  test_theme_set_exports_colors_and_runs_enabled_hooks
  test_theme_set_errors_without_colors_file
  test_theme_set_reports_hook_failure
  test_theme_set_sends_restart_notification
  test_qutebrowser_plugin_writes_theme_and_config
  test_qutebrowser_light_mode_change_requires_restart
  test_fzf_plugin_writes_fish_theme
  test_fish_plugin_writes_shell_colors
  test_foot_plugin_respects_disable_flag
  test_foot_plugin_logs_missing_theme_file
  test_foot_plugin_reads_theme_and_logs_no_ttys
  test_foot_plugin_writes_osc_sequences_to_tty
  test_cava_plugin_writes_theme_and_updates_config
  test_cava_plugin_does_not_duplicate_theme_setting
  test_superfile_plugin_writes_theme_and_requests_restart
  test_swaync_plugin_installs_theme_files_and_reloads
  test_swaync_plugin_prefers_named_theme_over_current_theme
  test_vscode_plugin_skips_when_theme_provides_vscode_json
  test_vscode_plugin_patches_extension_manifest_and_installs_theme
  test_theme_set_extracts_colors_with_leading_whitespace_and_comments
  test_install_preserves_disabled_plugins_and_installs_files
  test_install_interactive_prompt_installs_missing_adw_theme
  test_install_gum_prompt_installs_missing_adw_theme
  test_uninstall_removes_files_and_qutebrowser_theme
  test_uninstall_invokes_external_revert_commands

  if [[ "$TEST_FAILURES" -gt 0 ]]; then
    print_coverage_summary
    printf '\n%d test(s) failed.\n' "$TEST_FAILURES"
    exit 1
  fi

  print_coverage_summary
  printf '\nAll tests passed.\n'
}

main "$@"
