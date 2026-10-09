#!/usr/bin/env bash
# Zoo Breakout 回归门禁：跑全部 headless 套件。
# 失败条件：退出码非 0，或输出含 FAIL / FINDING / SCRIPT ERROR / ERROR:。
# 单套件超时 TEST_TIMEOUT 秒（默认180）。新增 class_name 后先跑 godot --headless --import 刷新类缓存。
# 用法：tools/run_tests.sh [suite ...]   （GODOT 环境变量可覆盖引擎路径）
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SUITES=("$@")
if [ ${#SUITES[@]} -eq 0 ]; then
  SUITES=(p0_regression p0_walkthrough p0_enclosure_check p0_climb_fly_repro
          p1_win_routes p1_monkey_walkthrough
          p2_outer_walls p2_run_reset p2_day_cycle p2_gather p2_capture p2_intel p2_route_work p2_cart p2_hygiene p2_ui p2_full_loop)
fi
LOG_DIR="${TMPDIR:-/tmp}/zoo_breakout_tests"
mkdir -p "$LOG_DIR"
failed=()
for s in "${SUITES[@]}"; do
  log="$LOG_DIR/$s.log"
  "$GODOT" --headless --path . "res://prototypes/$s.tscn" >"$log" 2>&1 &
  pid=$!
  ( sleep "${TEST_TIMEOUT:-180}"; kill -9 $pid 2>/dev/null ) &
  dog=$!
  wait $pid; code=$?
  kill $dog 2>/dev/null; wait $dog 2>/dev/null
  [ $code -eq 137 ] && echo "TIMEOUT" >>"$log"
  bad=$(grep -E '^(FAIL|FINDING|TIMEOUT)|SCRIPT ERROR|^ERROR:' "$log" | head -5)
  summary=$(grep -E 'SUMMARY|摘要' "$log" | tail -1)
  if [ $code -ne 0 ] || [ -n "$bad" ]; then
    printf '✗ %-26s exit=%d %s\n' "$s" "$code" "$summary"
    [ -n "$bad" ] && printf '%s\n' "$bad" | sed 's/^/    /'
    failed+=("$s")
  else
    printf '✓ %-26s %s\n' "$s" "$summary"
  fi
done
echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "ALL GREEN (${#SUITES[@]} suites) — logs: $LOG_DIR"
  exit 0
fi
echo "RED: ${failed[*]} — logs: $LOG_DIR"
exit 1
