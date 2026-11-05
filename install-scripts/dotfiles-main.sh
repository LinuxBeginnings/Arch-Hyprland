#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Hyprland-Dots to download from main

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_dotfiles.log"
DOTS_DIR="$PARENT_DIR/Hyprland-Dots"

section "KooL Hyprland dotfiles"

if [ -d "$DOTS_DIR" ]; then
  if [ ! -d "$DOTS_DIR/.git" ]; then
    error "$DOTS_DIR exists but is not a git repository. Move it away and rerun."
    exit 1
  fi

  step "Updating existing $DOTS_DIR"
  cd "$DOTS_DIR" || {
    error "Failed to change directory to $DOTS_DIR"
    exit 1
  }

  # Keep local changes instead of letting a pull fail on them
  if ! git stash push -m "install-$(date +%Y%m%d-%H%M%S)" >>"$LOG" 2>&1; then
    warn "Could not stash local changes in $DOTS_DIR; continuing."
  fi

  if ! git pull --ff-only >>"$LOG" 2>&1; then
    error "Could not update $DOTS_DIR. Resolve the git state and rerun."
    exit 1
  fi
else
  step "Cloning KooL's Hyprland Dots"
  if ! git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots "$DOTS_DIR"; then
    error "Can't download KooL's Hyprland-Dots. Check your internet connection."
    exit 1
  fi
  cd "$DOTS_DIR" || {
    error "Failed to change directory to $DOTS_DIR"
    exit 1
  }
fi

if [ ! -f copy.sh ]; then
  error "copy.sh not found in $DOTS_DIR. The dotfiles repository is incomplete."
  exit 1
fi

if ! chmod +x copy.sh; then
  warn "Could not mark copy.sh executable; running it with bash anyway."
fi

step "Applying dotfiles"
if ! bash copy.sh; then
  error "copy.sh failed; dotfiles were not fully installed."
  exit 1
fi

ok "KooL Hyprland dotfiles installed."
printf "\n%.0s" {1..2}
