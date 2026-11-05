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

# Shared colors, icons and console helpers (also used by the entry points)
# shellcheck source=colours.sh
source "$(dirname "${BASH_SOURCE[0]}")/colours.sh"

# Create the log directory once. A missing log must never abort an install.
if ! mkdir -p Install-Logs 2>/dev/null; then
  warn "Could not create Install-Logs; continuing without file logging."
fi

# Show progress while a background package install runs.
# Uses kill -0 instead of parsing `ps`, adds a non-TTY line, and never leaves
# the cursor hidden if the caller traps INT/TERM and calls restore_cursor.
show_progress() {
  local pid=$1
  local package_name=$2
  local spin_chars=("●○○○○○○○○○" "○●○○○○○○○○" "○○●○○○○○○○" "○○○●○○○○○○" "○○○○●○○○○" \
    "○○○○○●○○○○" "○○○○○○●○○○" "○○○○○○○●○○" "○○○○○○○○●○" "○○○○○○○○○●")
  local i=0
  local have_tty=0

  # Nothing to wait for (or a non-numeric pid): skip the spinner entirely
  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  if [ -t 1 ]; then
    have_tty=1
  fi

  if [ "$have_tty" -eq 1 ]; then
    tput civis 2>/dev/null || true
    printf '\r%s Installing %s%s%s ...' "$NOTE" "$YELLOW" "$package_name" "$RESET"
  else
    printf '%s Installing %s ...\n' "$NOTE" "$package_name"
  fi

  while kill -0 "$pid" 2>/dev/null; do
    if [ "$have_tty" -eq 1 ]; then
      printf '\r%s Installing %s%s%s %s' "$NOTE" "$YELLOW" "$package_name" "$RESET" "${spin_chars[i]}"
      i=$(((i + 1) % ${#spin_chars[@]}))
    fi
    sleep 0.2
  done

  if [ "$have_tty" -eq 1 ]; then
    printf '\r%s Finished %s%s%s.%-20s\n' "$NOTE" "$YELLOW" "$package_name" "$RESET" ""
    tput cnorm 2>/dev/null || true
  fi
  log_to_file "[STEP] Installing $package_name"
}

# Package install failures are recorded here so install.sh can print a summary
# at the end and exit non-zero instead of reporting success on an incomplete
# install. The install functions still return 0 on purpose: they are called
# bare in scripts that run under `set -e`, and one missing package must not
# abort the rest.
FAILED_PACKAGES_FILE="${FAILED_PACKAGES_FILE:-Install-Logs/.failed-packages}"

record_package_failure() {
  mkdir -p "${FAILED_PACKAGES_FILE%/*}" 2>/dev/null || true
  printf '%s\n' "$1" >>"$FAILED_PACKAGES_FILE"
}

# One `pacman -Qq` for the whole run instead of one `pacman -Q` per package, so
# a rerun on an already installed system spends its time installing, not
# querying.
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

# Installed version without epoch/pkgrel: "1:3.5.2-1" -> "3.5.2"
installed_version_of() {
  local raw=""
  raw="$(pacman -Q "$1" 2>/dev/null)" || return 1
  raw="${raw#* }"
  raw="${raw%%-*}"
  raw="${raw#*:}"
  [ -n "$raw" ] || return 1
  printf '%s\n' "$raw"
}

# Ask for sudo once and keep the timestamp alive for the whole run. Without
# this, a long install can stop halfway for a password prompt in a background
# job whose output is redirected to the log.
# Exported so shellcheck and callers can see it; the caller may stop the keepalive
export SUDO_KEEPALIVE_PID=""
request_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required but not installed."
    return 1
  fi

  if sudo -n true 2>/dev/null; then
    return 0
  fi

  note "Administrator privileges are required. Please authenticate."
  if ! sudo -v; then
    error "sudo authentication failed."
    return 1
  fi

  # Exit when the parent shell goes away, so no orphan process is left behind
  (
    while kill -0 "$$" 2>/dev/null; do
      sleep 50
      sudo -n true 2>/dev/null || exit 0
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
  return 0
}

# Install/force-reinstall with pacman and record failures.
_pacman_install() {
  local pkg="$1" log="$2" force="$3"
  local -a pacman_args=(-S --noconfirm --needed)
  local pid=0

  if [ "$force" -eq 1 ]; then
    pacman_args=(-S --noconfirm)
  fi

  (
    stdbuf -oL sudo pacman "${pacman_args[@]}" "$pkg" 2>&1
  ) >>"$log" 2>&1 &
  pid=$!
  show_progress "$pid" "$pkg"

  if pacman -Q "$pkg" &>/dev/null; then
    INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $pkg "
    echo -e "${OK} Package ${YELLOW}$pkg${RESET} has been successfully installed!"
    log_to_file "[OK] Package $pkg has been successfully installed"
  else
    record_package_failure "$pkg"
    echo -e "\n${ERROR} ${YELLOW}$pkg${RESET} failed to install. Please check the $log. You may need to install manually."
    log_to_file "[ERROR] $pkg failed to install"
  fi
}

# Function to install packages with pacman
install_package_pacman() {
  local pkg="$1" log="${2:-$LOG}"

  if package_is_installed "$pkg"; then
    echo -e "${INFO} ${MAGENTA}$pkg${RESET} is already installed. Skipping..."
    return 0
  fi

  _pacman_install "$pkg" "$log" 0
}

# Force a reinstall, needed when a package exists but its files are broken
reinstall_package_pacman() {
  local pkg="$1" log="${2:-$LOG}"
  _pacman_install "$pkg" "$log" 1
}

ISAUR="${ISAUR:-$(command -v yay || command -v paru || true)}"

# Fail loudly-but-safely when no AUR helper is available, instead of running an
# empty command ("if -Q pkg" is a syntax error).
require_aur_helper() {
  if [ -z "${ISAUR:-}" ]; then
    record_package_failure "$1"
    echo -e "${ERROR} Neither ${YELLOW}yay${RESET} nor ${YELLOW}paru${RESET} is available. Skipping AUR package ${YELLOW}$1${RESET}."
    log_to_file "[ERROR] No AUR helper; skipped $1"
    return 1
  fi
  return 0
}

# Function to install packages with either yay or paru
install_package() {
  local pkg="$1" log="${2:-$LOG}"
  local pid=0

  require_aur_helper "$pkg" || return 0

  if package_is_installed "$pkg"; then
    echo -e "${INFO} ${MAGENTA}$pkg${RESET} is already installed. Skipping..."
    return 0
  fi

  (
    stdbuf -oL "$ISAUR" -S --noconfirm --needed "$pkg" 2>&1
  ) >>"$log" 2>&1 &
  pid=$!
  show_progress "$pid" "$pkg"

  # Double check if package is installed
  if "$ISAUR" -Q "$pkg" &>/dev/null; then
    INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $pkg "
    echo -e "${OK} Package ${YELLOW}$pkg${RESET} has been successfully installed!"
    log_to_file "[OK] Package $pkg has been successfully installed"
  else
    record_package_failure "$pkg"
    echo -e "\n${ERROR} ${YELLOW}$pkg${RESET} failed to install :( , please check the $log. You may need to install manually! Sorry I have tried :("
    log_to_file "[ERROR] $pkg failed to install"
  fi
}

# Function to just install packages with either yay or paru without checking if installed
install_package_f() {
  local pkg="$1" log="${2:-$LOG}"
  local pid=0

  require_aur_helper "$pkg" || return 0

  (
    stdbuf -oL "$ISAUR" -S --noconfirm "$pkg" 2>&1
  ) >>"$log" 2>&1 &
  pid=$!
  show_progress "$pid" "$pkg"

  # Double check if package is installed
  if "$ISAUR" -Q "$pkg" &>/dev/null; then
    INSTALLED_PACKAGES_CACHE=" ${INSTALLED_PACKAGES_CACHE} $pkg "
    echo -e "${OK} Package ${YELLOW}$pkg${RESET} has been successfully installed!"
    log_to_file "[OK] Package $pkg has been successfully installed"
  else
    record_package_failure "$pkg"
    echo -e "\n${ERROR} ${YELLOW}$pkg${RESET} failed to install :( , please check the $log. You may need to install manually! Sorry I have tried :("
    log_to_file "[ERROR] $pkg failed to install"
  fi
}

# Function for removing packages
uninstall_package() {
  local pkg="$1"
  local pacman_status=0

  # Checking if package is installed
  if pacman -Qi "$pkg" &>/dev/null; then
    echo -e "${NOTE} removing $pkg ..."
    sudo pacman -R --noconfirm "$pkg" 2>&1 | tee -a "$LOG" | grep -v "error: target not found" || true
    pacman_status=${PIPESTATUS[0]}

    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo -e "\e[1A\e[K${OK} $pkg removed."
      log_to_file "[OK] Removed $pkg"
    else
      echo -e "\e[1A\e[K${ERROR} $pkg Removal failed. No actions required."
      log_to_file "[ERROR] Failed to remove $pkg (pacman exit $pacman_status)"
      return 1
    fi
  else
    echo -e "${INFO} Package $pkg not installed, skipping."
  fi
  return 0
}
