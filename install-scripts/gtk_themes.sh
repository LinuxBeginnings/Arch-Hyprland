#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# GTK Themes & ICONS and  Sourcing from a different Repo #

engine=(
    unzip
    gtk-engine-murrine
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
LOG_DIR="$PARENT_DIR/Install-Logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/install-$(date +%d-%H%M%S)_themes.log"


# installing engine needed for gtk themes
for PKG1 in "${engine[@]}"; do
    install_package "$PKG1" "$LOG"
done

# Check if the directory exists and delete it if present
if [ -d "GTK-themes-icons" ]; then
    echo "$NOTE GTK themes and Icons directory exist..deleting..." 2>&1 | tee -a "$LOG"
    rm -rf "GTK-themes-icons" 2>&1 | tee -a "$LOG"
fi

echo "$NOTE Cloning ${SKY_BLUE}GTK themes and Icons${RESET} repository..." 2>&1 | tee -a "$LOG"
if git clone --depth=1 https://github.com/LinuxBeginnings/GTK-themes-icons.git; then
    cd GTK-themes-icons || {
        echo "$ERROR Failed to change directory to GTK-themes-icons" 2>&1 | tee -a "$LOG"
        exit 1
    }
    if [ ! -f auto-extract.sh ]; then
        echo "$ERROR auto-extract.sh is missing from the GTK themes repository." | tee -a "$LOG"
        cd ..
        exit 1
    fi
    chmod +x auto-extract.sh || echo "$WARN Could not mark auto-extract.sh executable." | tee -a "$LOG"
    if ! bash auto-extract.sh; then
        echo "$ERROR Extracting the GTK themes failed." | tee -a "$LOG"
        cd ..
        exit 1
    fi
    cd ..
    echo "$OK Extracted GTK Themes & Icons to ~/.icons & ~/.themes directories" 2>&1 | tee -a "$LOG"
else
    echo "$ERROR Download failed for GTK themes and Icons.." 2>&1 | tee -a "$LOG"
    exit 1
fi

printf "\n%.0s" {1..2}