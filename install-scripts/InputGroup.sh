#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Adding users into input group #

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_input.log"

# Check if the 'input' group exists
if getent group input >/dev/null 2>&1; then
    echo "${OK} ${MAGENTA}input${RESET} group exists."
else
    echo "${NOTE} ${MAGENTA}input${RESET} group doesn't exist. Creating ${MAGENTA}input${RESET} group..."
    if ! sudo groupadd input; then
        echo "${ERROR} Could not create the input group." | tee -a "$LOG"
        exit 1
    fi
    echo "${MAGENTA}input${RESET} group created" | tee -a "$LOG"
fi

# Add the user to the 'input' group only if they are not a member yet
current_user="$(id -un)"
if id -nG "$current_user" | tr ' ' '\n' | grep -qx input; then
    echo "${NOTE} ${YELLOW}$current_user${RESET} is already in the ${MAGENTA}input${RESET} group. Nothing to do."
else
    if ! sudo usermod -aG input "$current_user"; then
        echo "${ERROR} Failed to add $current_user to the input group." | tee -a "$LOG"
        exit 1
    fi
    echo "${OK} ${YELLOW}$current_user${RESET} added to the ${MAGENTA}input${RESET} group. Changes take effect after you log out and log back in." | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}
