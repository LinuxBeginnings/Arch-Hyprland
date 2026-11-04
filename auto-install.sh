#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# https://github.com/LinuxBeginnings

# Shared color definitions
# shellcheck source=install-scripts/colours.sh
source "$(dirname "$(readlink -f "$0")")/install-scripts/colours.sh"

# Variables
Distro="Arch-Hyprland"
Github_URL="https://github.com/LinuxBeginnings/$Distro.git"
Distro_DIR="$HOME/$Distro"

printf "\n%.0s" {1..1}

if ! command -v git &> /dev/null
then
    echo "${INFO} Git not found! ${SKY_BLUE}Installing Git...${RESET}"
    if ! sudo pacman -S git --noconfirm; then
        echo "${ERROR} Failed to install Git. Exiting."
        exit 1
    fi
fi

printf "\n%.0s" {1..1}

if [ -d "$Distro_DIR" ]; then
    echo "${YELLOW}$Distro_DIR exists. Removing and performing a fresh clone... ${RESET}"
    rm -rf "$Distro_DIR"
else
    echo "${MAGENTA}$Distro_DIR does not exist. Cloning the repository...${RESET}"
fi

git clone --depth=1 "$Github_URL" "$Distro_DIR" || {
    echo "${ERROR} Failed to clone $Github_URL. Check your internet connection."
    exit 1
}

cd "$Distro_DIR" || {
    echo "${ERROR} Failed to change directory to $Distro_DIR."
    exit 1
}

chmod +x install.sh
./install.sh
