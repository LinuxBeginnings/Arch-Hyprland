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

is_compatible_version() {
  [[ "$1" =~ ^3\.5(\.|$) ]]
}

is_wallust_pinned() {
  awk '
    function has_wallust(value,   i, n, parts) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      n = split(value, parts, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (parts[i] == "wallust") {
          return 1
        }
      }
      return 0
    }
    BEGIN {
      in_options = 0
      found = 0
    }
    /^[[:space:]]*\[/ {
      in_options = ($0 ~ /^[[:space:]]*\[options\][[:space:]]*$/)
    }
    in_options && /^[[:space:]]*IgnorePkg[[:space:]]*=/ {
      line = $0
      sub(/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*/, "", line)
      if (has_wallust(line)) {
        found = 1
        exit
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$PACMAN_CONF"
}

ensure_ignore_pkg() {
  tmp_conf="$(mktemp)"
  awk '
    function has_wallust(value,   i, n, parts) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      n = split(value, parts, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (parts[i] == "wallust") {
          return 1
        }
      }
      return 0
    }
    BEGIN {
      in_options = 0
      saw_options = 0
      wrote_ignore = 0
    }
    /^[[:space:]]*\[/ {
      if (in_options && !wrote_ignore) {
        print "IgnorePkg = wallust"
        wrote_ignore = 1
      }
      in_options = ($0 ~ /^[[:space:]]*\[options\][[:space:]]*$/)
      if (in_options) {
        saw_options = 1
      }
      print
      next
    }
    !in_options && /^[[:space:]]*IgnorePkg[[:space:]]*=/ {
      line = $0
      sub(/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*/, "", line)
      if (has_wallust(line)) {
        next
      }
    }
    in_options && /^[[:space:]]*IgnorePkg[[:space:]]*=/ {
      line = $0
      sub(/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*/, "", line)
      if (has_wallust(line)) {
        print
      } else if (line == "") {
        print "IgnorePkg = wallust"
      } else {
        print "IgnorePkg = " line " wallust"
      }
      wrote_ignore = 1
      next
    }
    in_options && /^[[:space:]]*#[[:space:]]*IgnorePkg[[:space:]]*=/ && !wrote_ignore {
      print "IgnorePkg = wallust"
      wrote_ignore = 1
      next
    }
    {
      print
    }
    END {
      if (in_options && !wrote_ignore) {
        print "IgnorePkg = wallust"
      } else if (!saw_options) {
        print ""
        print "[options]"
        print "IgnorePkg = wallust"
      }
    }
  ' "$PACMAN_CONF" > "$tmp_conf" || {
    rm -f "$tmp_conf"
    echo -e "${ERROR} Failed to update ${YELLOW}$PACMAN_CONF${RESET}."
    return 1
  }

  if ! cmp -s "$tmp_conf" "$PACMAN_CONF"; then
    sudo cp "$tmp_conf" "$PACMAN_CONF" || {
      rm -f "$tmp_conf"
      echo -e "${ERROR} Failed to write ${YELLOW}$PACMAN_CONF${RESET}."
      return 1
    }
  fi
  rm -f "$tmp_conf"

  if is_wallust_pinned; then
    echo -e "${OK} wallust pinned in ${YELLOW}$PACMAN_CONF${RESET} via IgnorePkg."
    return 0
  fi

  echo -e "${ERROR} Failed to pin wallust in ${YELLOW}$PACMAN_CONF${RESET}."
  return 1
}

if [ -n "$installed_version" ] && is_compatible_version "$installed_version"; then
  echo -e "${INFO} wallust ${YELLOW}$installed_version${RESET} is compatible (3.5.x)."
  ensure_ignore_pkg || exit 1
  exit 0
fi

if [ -n "$installed_version" ]; then
  if [[ "$installed_version" =~ ^4\. ]]; then
    echo -e "${NOTE} Incompatible wallust ${YELLOW}$installed_version${RESET} detected. Downgrading to ${YELLOW}$TARGET_VERSION${RESET}."
  else
    echo -e "${NOTE} Unsupported wallust ${YELLOW}$installed_version${RESET} detected. Installing ${YELLOW}$TARGET_VERSION${RESET}."
  fi
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
  if is_compatible_version "$new_version"; then
    echo -e "${OK} wallust ${YELLOW}$new_version${RESET} installed successfully."
    ensure_ignore_pkg || exit 1
  else
    echo -e "${ERROR} wallust installed but version is ${YELLOW}$new_version${RESET}. Expected 3.5.x."
    exit 1
  fi
else
  echo -e "${ERROR} wallust installation failed. Please check ${YELLOW}$LOG${RESET}."
  exit 1
fi
