#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Nvidia Blacklist

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || {
  echo "${ERROR} Failed to change directory to $PARENT_DIR"
  exit 1
}

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_nouveau.log"

section "Blacklisting nouveau"
NOUVEAU="/etc/modprobe.d/nouveau.conf"
BLACKLIST_CONF="/etc/modprobe.d/blacklist.conf"

if [ -f "$NOUVEAU" ] && grep -qx 'blacklist nouveau' "$NOUVEAU"; then
  note "nouveau is already blacklisted in $NOUVEAU."
else
  step "Writing the nouveau blacklist to $NOUVEAU"
  # shellcheck disable=SC2024 # the log file is owned by the invoking user
  if ! printf '%s\n' "blacklist nouveau" | sudo tee -a "$NOUVEAU" >>"$LOG" 2>&1; then
    warn "Could not write to $NOUVEAU."
  fi
fi

# To completely blacklist nouveau (see wiki.archlinux.org/title/Kernel_module#Blacklisting)
if grep -q '^install nouveau /bin/true' "$BLACKLIST_CONF" 2>/dev/null; then
  note "The nouveau install override already exists in $BLACKLIST_CONF."
else
  step "Adding the nouveau install override to $BLACKLIST_CONF"
  # shellcheck disable=SC2024 # the log file is owned by the invoking user
  if ! printf '%s\n' "install nouveau /bin/true" | sudo tee -a "$BLACKLIST_CONF" >>"$LOG" 2>&1; then
    warn "Could not write to $BLACKLIST_CONF."
  fi
fi

if grep -qx 'blacklist nouveau' "$NOUVEAU" 2>/dev/null &&
  grep -q '^install nouveau /bin/true' "$BLACKLIST_CONF" 2>/dev/null; then
  ok "nouveau is blacklisted. Rebuild the initramfs (mkinitcpio -P) and reboot."
else
  warn "nouveau blacklisting is incomplete. Check $LOG."
fi

printf "\n%.0s" {1..2}
