#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Global Functions for Scripts #

set -e

# Shared color definitions
# shellcheck source=colours.sh
source "$(dirname "${BASH_SOURCE[0]}")/colours.sh"

# Create Directory for Install Logs
if [ ! -d Install-Logs ]; then
    mkdir Install-Logs
fi

# Show progress function
show_progress() {
    local pid=$1
    local package_name=$2
    local spin_chars=("●○○○○○○○○○" "○●○○○○○○○○" "○○●○○○○○○○" "○○○●○○○○○○" "○○○○●○○○○" \
                      "○○○○○●○○○○" "○○○○○○●○○○" "○○○○○○○●○○" "○○○○○○○○●○" "○○○○○○○○○●") 
    local i=0

    # Nothing to wait for (or a non-numeric pid): skip the spinner entirely
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    tput civis 
    printf "\r${NOTE} Installing ${YELLOW}%s${RESET} ..." "$package_name"

    while ps -p $pid &> /dev/null; do
        printf "\r${NOTE} Installing ${YELLOW}%s${RESET} %s" "$package_name" "${spin_chars[i]}"
        i=$(( (i + 1) % 10 ))  
        sleep 0.3  
    done

    printf "\r${NOTE} Installing ${YELLOW}%s${RESET} ... Done!%-20s \n" "$package_name" ""
    tput cnorm  
}


# Package install failures are recorded here so install.sh can print a summary at
# the end and exit non-zero instead of reporting success on an incomplete install.
# The install functions still return 0 on purpose: they are called bare in scripts
# that run under `set -e`, and one missing package must not abort the rest.
FAILED_PACKAGES_FILE="Install-Logs/.failed-packages"

record_package_failure() {
  mkdir -p "${FAILED_PACKAGES_FILE%/*}" 2>/dev/null || true
  printf '%s\n' "$1" >>"$FAILED_PACKAGES_FILE"
}

# One `pacman -Qq` for the whole run instead of one `pacman -Q` per package, so a
# rerun on an already installed system spends its time installing, not querying.
INSTALLED_PACKAGES_CACHE=""
INSTALLED_PACKAGES_LOADED=0

package_is_installed() {
  if [ "$INSTALLED_PACKAGES_LOADED" -eq 0 ]; then
    INSTALLED_PACKAGES_CACHE=" $(pacman -Qq 2>/dev/null | tr '\n' ' ') "
    INSTALLED_PACKAGES_LOADED=1
  fi

  # Quoted, so a package name is matched literally and not as a glob
  case "$INSTALLED_PACKAGES_CACHE" in
  *" $1 "*) return 0 ;;
  esac

  # Not in the snapshot, it may have been installed after it was taken
  pacman -Q "$1" &>/dev/null
}

# Function to install packages with pacman
install_package_pacman() {
  # Check if package is already installed
  if package_is_installed "$1" ; then
    echo -e "${INFO} ${MAGENTA}$1${RESET} is already installed. Skipping..."
  else
    # Run pacman and redirect all output to a log file
    (
      stdbuf -oL sudo pacman -S --noconfirm "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1" 

    # Double check if package is installed
    if pacman -Q "$1" &>/dev/null ; then
      INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $1 "
      echo -e "${OK} Package ${YELLOW}$1${RESET} has been successfully installed!"
    else
      record_package_failure "$1"
      echo -e "\n${ERROR} ${YELLOW}$1${RESET} failed to install. Please check the $LOG. You may need to install manually."
    fi
  fi
}

ISAUR=$(command -v yay || command -v paru)

# Fail loudly-but-safely when no AUR helper is available, instead of running an
# empty command ("if -Q pkg" is a syntax error).
require_aur_helper() {
  if [ -z "$ISAUR" ]; then
    echo -e "${ERROR} Neither ${YELLOW}yay${RESET} nor ${YELLOW}paru${RESET} is available. Skipping AUR package ${YELLOW}$1${RESET}."
    return 1
  fi
  return 0
}

# Function to install packages with either yay or paru
install_package() {
  require_aur_helper "$1" || return 0

  if package_is_installed "$1" ; then
    echo -e "${INFO} ${MAGENTA}$1${RESET} is already installed. Skipping..."
  else
    (
      stdbuf -oL $ISAUR -S --noconfirm "$1" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "$1"  
    
    # Double check if package is installed
    if $ISAUR -Q "$1" &>> /dev/null ; then
      INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $1 "
      echo -e "${OK} Package ${YELLOW}$1${RESET} has been successfully installed!"
    else
      # Something is missing, exiting to review log
      record_package_failure "$1"
      echo -e "\n${ERROR} ${YELLOW}$1${RESET} failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
    fi
  fi
}

# Function to just install packages with either yay or paru without checking if installed
install_package_f() {
  require_aur_helper "$1" || return 0

  (
    stdbuf -oL $ISAUR -S --noconfirm "$1" 2>&1
  ) >> "$LOG" 2>&1 &
  PID=$!
  show_progress $PID "$1"  

  # Double check if package is installed
  if $ISAUR -Q "$1" &>> /dev/null ; then
    INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $1 "
    echo -e "${OK} Package ${YELLOW}$1${RESET} has been successfully installed!"
  else
    # Something is missing, exiting to review log
    echo -e "\n${ERROR} ${YELLOW}$1${RESET} failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
  fi
}


# Function for removing packages
uninstall_package() {
  local pkg="$1"

  # Checking if package is installed
  if pacman -Qi "$pkg" &>/dev/null; then
    echo -e "${NOTE} removing $pkg ..."
    sudo pacman -R --noconfirm "$pkg" 2>&1 | tee -a "$LOG" | grep -v "error: target not found"
    
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo -e "\e[1A\e[K${OK} $pkg removed."
    else
      echo -e "\e[1A\e[K${ERROR} $pkg Removal failed. No actions required."
      return 1
    fi
  else
    echo -e "${INFO} Package $pkg not installed, skipping."
  fi
  return 0
}