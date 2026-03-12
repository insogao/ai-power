#!/bin/zsh
set -euo pipefail

LOG_FILE="${AI_POWER_COUNTER_LOG:-/tmp/ai_power_closed_lid_counter.log}"
PID_FILE="${AI_POWER_COUNTER_PID:-/tmp/ai_power_closed_lid_counter.pid}"

cleanup() {
  rm -f "$PID_FILE"
}

trap cleanup EXIT INT TERM

echo "$$" > "$PID_FILE"
echo "=== AI Power closed-lid counter started at $(date '+%F %T') ===" >> "$LOG_FILE"

count=1
while true; do
  printf '%s count=%d\n' "$(date '+%F %T')" "$count" | tee -a "$LOG_FILE"
  count=$((count + 1))
  sleep 1
done
