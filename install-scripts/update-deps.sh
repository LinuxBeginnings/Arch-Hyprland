#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Update dependencies and summarize results

## Repo-specific script names (override via env if needed)
INSTALL_SCRIPT_NAME="${INSTALL_SCRIPT_NAME:-01-hypr-pkgs.sh}"
CHECK_SCRIPT_NAME="${CHECK_SCRIPT_NAME:-02-Final-Check.sh}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
LOG_DIR="$PARENT_DIR/Install-Logs"

mkdir -p "$LOG_DIR"
cd "$PARENT_DIR" || {
  echo "Failed to change directory to $PARENT_DIR"
  exit 1
}

INSTALL_SCRIPT="$SCRIPT_DIR/$INSTALL_SCRIPT_NAME"
CHECK_SCRIPT="$SCRIPT_DIR/$CHECK_SCRIPT_NAME"

if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "Install script not found: $INSTALL_SCRIPT"
  exit 1
fi

if [ ! -f "$CHECK_SCRIPT" ]; then
  echo "Check script not found: $CHECK_SCRIPT"
  exit 1
fi

RUN_STAMP="$(date +%d-%H%M%S)"
INSTALL_LOG="$LOG_DIR/update-deps-${RUN_STAMP}_install.log"
CHECK_LOG="$LOG_DIR/update-deps-${RUN_STAMP}_check.log"

strip_ansi() {
  sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

echo "Running install script: $INSTALL_SCRIPT_NAME"
bash "$INSTALL_SCRIPT" 2>&1 | tee "$INSTALL_LOG"
install_status=${PIPESTATUS[0]}

echo
echo "Running final check: $CHECK_SCRIPT_NAME"
bash "$CHECK_SCRIPT" 2>&1 | tee "$CHECK_LOG"
check_status=${PIPESTATUS[0]}

clean_install_log="$(mktemp)"
clean_check_log="$(mktemp)"
strip_ansi < "$INSTALL_LOG" > "$clean_install_log"
strip_ansi < "$CHECK_LOG" > "$clean_check_log"

mapfile -t installed_pkgs < <(awk '/\[OK\] Package /{print $3}' "$clean_install_log" | sort -u)
mapfile -t failed_pkgs < <(awk '/failed to install/{print $2}' "$clean_install_log" | sort -u)

latest_final_log="$(ls -t "$LOG_DIR"/00_CHECK-*_installed.log 2>/dev/null | head -n 1)"
missing_pkgs=()
if [ -n "$latest_final_log" ] && [ -f "$latest_final_log" ]; then
  mapfile -t missing_pkgs < <(strip_ansi < "$latest_final_log" | awk 'NF==1')
fi

rm -f "$clean_install_log" "$clean_check_log"

echo
echo "Summary"
echo "-------"
echo "Install script: $INSTALL_SCRIPT_NAME"
echo "Final check script: $CHECK_SCRIPT_NAME"
echo "Install exit status: $install_status"
echo "Check exit status: $check_status"
echo

if [ ${#installed_pkgs[@]} -gt 0 ]; then
  echo "Installed packages (${#installed_pkgs[@]}): ${installed_pkgs[*]}"
else
  echo "Installed packages: none detected"
fi

if [ ${#failed_pkgs[@]} -gt 0 ]; then
  echo "Failed installs (${#failed_pkgs[@]}): ${failed_pkgs[*]}"
else
  echo "Failed installs: none detected"
fi

if [ ${#missing_pkgs[@]} -gt 0 ]; then
  echo "Missing packages from final check (${#missing_pkgs[@]}): ${missing_pkgs[*]}"
else
  echo "Missing packages from final check: none detected"
fi
