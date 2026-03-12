#!/bin/zsh
set -euo pipefail

LABEL="com.aipower.continuity-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/Library/PrivilegedHelperTools/AIPowerContinuityHelper"
RECOVERY_FILE="/tmp/com.aipower.continuity-helper.json"

echo "Resetting AI Power closed-lid access..."

if launchctl print "system/${LABEL}" >/dev/null 2>&1; then
  sudo launchctl bootout "system/${LABEL}" || true
fi

if [[ -f "$RECOVERY_FILE" ]]; then
  echo "Restoring pmset baseline from recovery journal..."

  sleep_minutes="$(/usr/bin/plutil -extract baseline.sleepMinutes raw -o - "$RECOVERY_FILE" 2>/dev/null || true)"
  display_sleep_minutes="$(/usr/bin/plutil -extract baseline.displaySleepMinutes raw -o - "$RECOVERY_FILE" 2>/dev/null || true)"
  disk_sleep_minutes="$(/usr/bin/plutil -extract baseline.diskSleepMinutes raw -o - "$RECOVERY_FILE" 2>/dev/null || true)"
  sleep_disabled_raw="$(/usr/bin/plutil -extract baseline.sleepDisabled raw -o - "$RECOVERY_FILE" 2>/dev/null || true)"

  [[ -n "$sleep_minutes" ]] && sudo /usr/bin/pmset -a sleep "$sleep_minutes" || true
  [[ -n "$display_sleep_minutes" ]] && sudo /usr/bin/pmset -a displaysleep "$display_sleep_minutes" || true
  [[ -n "$disk_sleep_minutes" ]] && sudo /usr/bin/pmset -a disksleep "$disk_sleep_minutes" || true

  if [[ "$sleep_disabled_raw" == "true" || "$sleep_disabled_raw" == "1" ]]; then
    sudo /usr/bin/pmset -a disablesleep 1 || true
  elif [[ "$sleep_disabled_raw" == "false" || "$sleep_disabled_raw" == "0" ]]; then
    sudo /usr/bin/pmset -a disablesleep 0 || true
  fi
fi

sudo rm -f "$DAEMON_PLIST"
sudo rm -f "$HELPER_BIN"
sudo rm -f "$RECOVERY_FILE"

echo "Done."
echo "If System Settings still shows old approval state, run:"
echo "  sudo sfltool resetbtm"
echo "Then log out and back in."
