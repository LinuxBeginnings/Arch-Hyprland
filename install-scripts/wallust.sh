#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Wallust 3.5.2 (AUR tarball) installer #

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_wallust.log"

ARCHIVE_PATH="$SCRIPT_DIR/wallust-3.5.2.tar.gz"
TARGET_VERSION="3.5.2"
PACMAN_CONF="/etc/pacman.conf"

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo -e "${ERROR} Missing archive: ${YELLOW}$ARCHIVE_PATH${RESET}"
  exit 1
fi

installed_version=""
if pacman -Qi wallust &>/dev/null; then
  installed_version="$(pacman -Qi wallust | awk -F': ' '/Version/{print $2}' | cut -d- -f1)"
fi

ensure_ignore_pkg() {
  if grep -qE '^[[:space:]]*IgnorePkg[[:space:]]*=' "$PACMAN_CONF"; then
    if ! grep -qE '^[[:space:]]*IgnorePkg[[:space:]]*=.*\bwallust\b' "$PACMAN_CONF"; then
      sudo sed -i -E 's/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*/&wallust /' "$PACMAN_CONF"
    fi
  else
    printf "\n# Added by Arch-Hyprland install-scripts/wallust.sh\nIgnorePkg = wallust\n" | sudo tee -a "$PACMAN_CONF" >/dev/null
  fi
}

if [ -n "$installed_version" ] && [ "$installed_version" = "$TARGET_VERSION" ]; then
  echo -e "${INFO} wallust ${YELLOW}$installed_version${RESET} already installed. Adding to IgnorePkg."
  ensure_ignore_pkg
  exit 0
fi

if [ -n "$installed_version" ]; then
  echo -e "${NOTE} wallust ${YELLOW}$installed_version${RESET} detected. Removing it before installing ${YELLOW}$TARGET_VERSION${RESET}."
  uninstall_package "wallust"
fi

printf "%s - Installing ${SKY_BLUE}wallust ${TARGET_VERSION}${RESET} from bundled tarball... \n" "${NOTE}"

BUILD_DIR="$(mktemp -d)"
tar -xf "$ARCHIVE_PATH" -C "$BUILD_DIR"

PKG_DIR="$(find "$BUILD_DIR" -maxdepth 1 -type d -name "wallust*" -print -quit)"
if [ -z "$PKG_DIR" ]; then
  echo -e "${ERROR} Failed to locate extracted wallust directory."
  rm -rf "$BUILD_DIR"
  exit 1
fi

pushd "$PKG_DIR" >/dev/null
makepkg -si --noconfirm 2>&1 | tee -a "$LOG"
popd >/dev/null

rm -rf "$BUILD_DIR"

if pacman -Qi wallust &>/dev/null; then
  new_version="$(pacman -Qi wallust | awk -F': ' '/Version/{print $2}' | cut -d- -f1)"
  if [ "$new_version" = "$TARGET_VERSION" ]; then
    echo -e "${OK} wallust ${YELLOW}$TARGET_VERSION${RESET} installed successfully."
    ensure_ignore_pkg
  else
    echo -e "${WARN} wallust installed but version is ${YELLOW}$new_version${RESET}. Please verify."
  fi
else
  echo -e "${ERROR} wallust installation failed. Please check ${YELLOW}$LOG${RESET}."
  exit 1
fi
