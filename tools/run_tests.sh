#!/usr/bin/env bash
# Borrowed Shapes 核心門禁：預設只驗證 form_lab。
# 其他既有套件僅於使用者明確要求時指定執行。
# 退出碼非0，或ERROR／WARNING／FAIL／FINDING／TIMEOUT即停止。
# 用法：tools/run_tests.sh [form_lab|movement_lab|suite ...]
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SUITES=("$@")
if [ ${#SUITES[@]} -eq 0 ]; then
  SUITES=(form_lab)
fi
LOG_DIR="${TEST_LOG_DIR:-${TMPDIR:-/tmp}/borrowed_shapes_tests}"
mkdir -p "$LOG_DIR"
for s in "${SUITES[@]}"; do
  args=("$GODOT" --headless --path .)
  case "$s" in
    form_lab) scene="res://scenes/forms/form_lab.tscn"; args=("${args[@]}" --fixed-fps 60 --quit-after 180) ;;
    movement_lab) scene="res://scenes/traversal/movement_lab.tscn"; args=("${args[@]}" --quit-after 120) ;;
    *) scene="res://prototypes/$s.tscn" ;;
  esac
  if [ ! -f "${scene#res://}" ]; then
    printf 'ERROR: 找不到套件場景：%s\n' "$scene"
    exit 1
  fi
  log="$LOG_DIR/$s.log"
  "${args[@]}" "$scene" >"$log" 2>&1 &
  pid=$!
  ( sleep "${TEST_TIMEOUT:-180}"; kill -9 "$pid" 2>/dev/null ) &
  dog=$!
  while kill -0 "$pid" 2>/dev/null; do
    if grep -Eq '^(FAIL|FINDING|TIMEOUT)|SCRIPT ERROR|(^|[[:space:]])(ERROR:|WARNING:)|[Cc]rashed' "$log"; then
      kill "$pid" 2>/dev/null
      break
    fi
    sleep 0.1
  done
  wait "$pid"; code=$?
  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  [ "$code" -eq 137 ] && echo "TIMEOUT" >>"$log"
  bad=$(grep -E '^(FAIL|FINDING|TIMEOUT)|SCRIPT ERROR|(^|[[:space:]])(ERROR:|WARNING:)|[Cc]rashed' "$log" | head -5)
  summary=$(grep -E 'SUMMARY|摘要' "$log" | tail -1)
  if [ "$code" -ne 0 ] || [ -n "$bad" ]; then
    printf '✗ %-26s exit=%d %s\n' "$s" "$code" "$summary"
    [ -n "$bad" ] && printf '%s\n' "$bad" | sed 's/^/    /'
    printf 'RED: %s — logs: %s\n' "$s" "$LOG_DIR"
    exit 1
  fi
  printf '✓ %-26s %s\n' "$s" "$summary"
done
printf '\nALL GREEN (%d checks) — logs: %s\n' "${#SUITES[@]}" "$LOG_DIR"
