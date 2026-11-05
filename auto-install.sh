#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Clone the installer and run it, forwarding any options

# Shared color, icon and console helpers
# shellcheck source=install-scripts/colours.sh
source "$(dirname "$(readlink -f "$0")")/install-scripts/colours.sh"

# Variables
Distro="Arch-Hyprland"
Github_URL="https://github.com/LinuxBeginnings/$Distro.git"
Distro_DIR="$HOME/$Distro"

ASSUME_YES=0
INSTALL_ARGS=()

usage() {
  cat <<EOF
Usage: $0 [--yes] [install.sh options]

  -y, --yes   Replace an existing $Distro_DIR without asking
  -h, --help  Show this help and exit

All other options are passed to install.sh (for example --dry-run or
--preset <file>).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  -y | --yes)
    ASSUME_YES=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    INSTALL_ARGS+=("$1")
    shift
    ;;
  esac
done

print_banner "Auto-install"

if ! command -v pacman >/dev/null 2>&1; then
  error "pacman not found. This installer targets Arch Linux."
  exit 1
fi

if [ "$EUID" -eq 0 ]; then
  error "Do not run this script as root. Run it as the user who will use Hyprland."
  exit 1
fi

if ! command -v git &>/dev/null; then
  info "Git not found! Installing Git..."
  if ! sudo pacman -S --needed --noconfirm git; then
    error "Failed to install Git. Exiting."
    exit 1
  fi
fi

printf "\n%.0s" {1..1}

if [ -d "$Distro_DIR" ]; then
  warn "$Distro_DIR already exists."
  if [ "$ASSUME_YES" -ne 1 ]; then
    printf '%s Replace it with a fresh clone? [y/N]: ' "$CAT"
    read -r reply || reply=""
    case "$reply" in
    [yY] | [yY][eE][sS]) ;;
    *)
      note "Aborted. Existing directory left untouched."
      exit 0
      ;;
    esac
  fi

  step "Removing $Distro_DIR"
  if ! rm -rf -- "$Distro_DIR"; then
    error "Could not remove $Distro_DIR."
    exit 1
  fi
else
  info "$Distro_DIR does not exist. Cloning the repository..."
fi

if ! git clone --depth=1 "$Github_URL" "$Distro_DIR"; then
  error "Failed to clone $Github_URL. Check your internet connection."
  rm -rf -- "$Distro_DIR"
  exit 1
fi

cd "$Distro_DIR" || {
  error "Failed to change directory to $Distro_DIR."
  exit 1
}

if ! chmod +x install.sh; then
  warn "Could not mark install.sh executable."
fi

# exec keeps the installer's exit status and avoids leaving this shell around
exec bash ./install.sh "${INSTALL_ARGS[@]}"
