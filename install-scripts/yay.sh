#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Yay AUR Helper #
# NOTE: If paru is already installed, yay will not be installed #

pkg="yay-bin"

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
# Catch failures inside `cmd | tee` pipelines
set -o pipefail

# Shared color definitions
# shellcheck source=colours.sh
source "$(dirname "$(readlink -f "$0")")/colours.sh"

# Create Directory for Install Logs
if ! mkdir -p Install-Logs; then
    printf '%s Could not create Install-Logs.\n' "$ERROR"
    exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_yay.log"

# Check for AUR helper and install if not found
ISAUR=$(command -v yay || command -v paru)
if [ -n "$ISAUR" ]; then
  printf "\n%s - ${SKY_BLUE}AUR helper${RESET} already installed, moving on.\n" "${OK}"
else
  printf "\n%s - Installing ${SKY_BLUE}$pkg${RESET} from AUR\n" "${NOTE}"

# Check if directory exists and remove it
if [ -d "$pkg" ]; then
    rm -rf "$pkg"
fi
  git clone "https://aur.archlinux.org/$pkg.git" || { printf "%s - Failed to clone ${YELLOW}$pkg${RESET} from AUR\n" "${ERROR}"; exit 1; }
  cd "$pkg" || { printf "%s - Failed to enter $pkg directory\n" "${ERROR}"; exit 1; }
  makepkg -si --noconfirm 2>&1 | tee -a "$LOG" || { printf "%s - Failed to install ${YELLOW}$pkg${RESET} from AUR\n" "${ERROR}"; exit 1; }

  # moving install logs in to Install-Logs directory
  mv install*.log ../Install-Logs/ || true   
  cd ..
fi

# Update system before proceeding
printf "\n%s - Performing a full system update to avoid issues.... \n" "${NOTE}"
ISAUR=$(command -v yay || command -v paru)
if [ -z "$ISAUR" ]; then
  printf "%s - AUR helper not found. Cannot continue.\n" "${ERROR}"
  exit 1
fi

$ISAUR -Syu --noconfirm 2>&1 | tee -a "$LOG" || { printf "%s - Failed to update system\n" "${ERROR}"; exit 1; }

printf "\n%.0s" {1..2}