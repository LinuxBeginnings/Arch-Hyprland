#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Asus ROG Laptops #

rog=(
    power-profiles-daemon
    asusctl
    supergfxctl
    rog-control-center
)

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi



# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_rog.log"

### Install software for Asus ROG laptops ###

printf "${NOTE} Installing ${SKY_BLUE}ASUS ROG packages${RESET}...\n"
for ASUS in "${rog[@]}"; do
  install_package "$ASUS" "$LOG"
done

# TLP and power-profiles-daemon fight over the same power settings
if systemctl is-active --quiet tlp 2>/dev/null; then
  warn "tlp is active and conflicts with power-profiles-daemon. Disable tlp if power profiles misbehave."
fi

printf "${NOTE} Activating ROG services...\n"
for unit in supergfxd.service power-profiles-daemon.service; do
  if ! systemctl list-unit-files "$unit" 2>/dev/null | grep -q "^$unit"; then
    warn "$unit was not found; skipping."
    continue
  fi
  if sudo systemctl enable --now "$unit" 2>&1 | tee -a "$LOG"; then
    echo "${OK} $unit enabled."
  else
    warn "Could not enable $unit. Check $LOG."
  fi
done

printf "\n%.0s" {1..2}