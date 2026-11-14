#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# KooL Arch-Hyprland uninstall script #

# Shared color, icon and console helpers
# shellcheck source=install-scripts/colours.sh
source "$(dirname "$(readlink -f "$0")")/install-scripts/colours.sh"

trap restore_cursor EXIT
trap 'restore_cursor; exit 130' INT TERM

clear
print_banner "Uninstall"

if [ "$EUID" -eq 0 ]; then
  error "Do not run this uninstaller as root: it must remove files from your own HOME."
  exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
  error "whiptail is required for the uninstall menu. Install it with: sudo pacman -S libnewt"
  exit 1
fi

# Log every removal attempt so failures can be reviewed afterwards
if ! mkdir -p Install-Logs; then
  error "Could not create the Install-Logs directory."
  exit 1
fi
LOG="Install-Logs/uninstall-$(date +%d-%H%M%S).log"

# Show welcome message using whiptail with Yes/No options
if ! whiptail --title "Arch-Hyprland KooL Dots Uninstall Script" --yesno \
  "Hello! This script will uninstall KooL Hyprland packages and configs.

You can choose packages and directories you want to remove.
NOTE: This will remove configs from ~/.config

WARNING: After uninstallation, your system may become unstable.

Shall we Proceed?" 20 80; then
  note "Uninstall cancelled."
  exit 0
fi

# Selections are written here and reused for the retry/report loops.
# mktemp keeps the file names unpredictable, so another local user cannot
# pre-create a symlink and redirect the writes.
SELECTION_DIR="$(mktemp -d)" || {
  error "Could not create a temporary directory."
  exit 1
}
chmod 700 "$SELECTION_DIR"
SELECTED_PACKAGES_FILE="$SELECTION_DIR/packages.txt"
SELECTED_DIRECTORIES_FILE="$SELECTION_DIR/directories.txt"

cleanup_selection_files() {
  rm -rf -- "$SELECTION_DIR"
}
trap 'cleanup_selection_files; restore_cursor' EXIT
trap 'cleanup_selection_files; restore_cursor; exit 130' INT TERM

# Collected so the run can report exactly what it could not remove
failed_packages=()
failed_dirs=()
failed_local=()
still_installed=()

# Function to remove selected packages
remove_packages() {
  local file=$1
  local package=""
  local pacman_status=0

  while IFS= read -r package; do
    [ -n "$package" ] || continue

    if ! pacman -Qi "$package" &>/dev/null; then
      note "Package $package is not installed. Skipping."
      continue
    fi

    step "Removing package: $package"
    sudo pacman -Rs --noconfirm "$package" 2>&1 | tee -a "$LOG"
    pacman_status=${PIPESTATUS[0]}

    if [ "$pacman_status" -eq 0 ] && ! pacman -Qi "$package" &>/dev/null; then
      ok "Removed package: $package"
      log_to_file "[OK] Removed package $package"
    else
      error "Failed to remove package: $package (details in $LOG)"
      failed_packages+=("$package")
    fi
  done <"$file"
}

# Function to remove selected directories
remove_directories() {
  local file=$1
  local dir=""
  local dir_to_remove=""

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue

    # Only allow plain names inside ~/.config, never paths or parent references
    case "$dir" in
    */* | . | ..)
      warn "Skipping unsafe directory entry: $dir"
      continue
      ;;
    esac

    for dir_to_remove in "$HOME/.config/$dir"*; do
      [ -d "$dir_to_remove" ] || continue
      step "Removing directory: $dir_to_remove"
      if rm -rf -- "$dir_to_remove"; then
        ok "Removed directory: $dir_to_remove"
        log_to_file "[OK] Removed directory $dir_to_remove"
      else
        error "Failed to remove directory: $dir_to_remove"
        failed_dirs+=("$dir_to_remove")
      fi
    done
  done <"$file"
}

# Define the list of packages to choose from (with options_command tags)
packages=(
<<<<<<< HEAD
  "btop" "resource monitor" "off"
  "brightnessctl" "brightnessctl" "off"
  "cava" "Cross-platform Audio Visualizer" "off"
  "cliphist" "clipboard manager" "off"
  "fastfetch" "fastfetch" "off"
  "ffmpegthumbnailer" "FFmpeg Thumbnailer" "off"
  "grim" "screenshot tool" "off"
  "imagemagick" "Image manipulation tool" "off"
  "kitty" "kitty-terminal" "off"
  "kvantum" "QT apps theming" "off"
  "kvantum-qt5" "QT apps theming" "off"
  "qt5-declarative" "QT apps theming" "off"
  "qt5-quickcontrols2" "QT apps theming" "off"
  "mousepad" "simple text editor" "off"
  "mpv" "multi-media player" "off"
  "mpv-mpris" "mpv-plugin" "off"
  "network-manager-applet" "network-manager-applet" "off"
  "nvtop" "gpu resource monitor" "off"
  "nwg-displays" "display monitor configuration app" "off"
  "nwg-look" "gtk settings app" "off"
  "pamixer" "pamixer" "off"
  "pokemon-colorscripts-git" "terminal colorscripts" "off"
  "pavucontrol" "pavucontrol" "off"
  "playerctl" "playerctl" "off"
  "pyprland" "pyprland" "off"
  "qalculate-gtk" "calculator - QT" "off"
  "qt5ct" "qt5ct" "off"
  "qt6ct" "qt6ct" "off"
  "qt6-declarative" "QT apps theming" "off"
  "rofi" "rofi launcher" "off"
  "slurp" "screenshot tool" "off"
  "swappy" "screenshot tool" "off"
  "swaync" "notification agent" "off"
  "awww" "wallpaper engine" "off"
  "thunar" "File Manager" "off"
  "thunar-archive-plugin" "Archive Plugin" "off"
  "thunar-volman" "Volume Management" "off"
  "tumbler" "Thumbnail Service" "off"
  "wallust" "color pallete generator" "off"
  "waybar" "wayland bar" "off"
  "waybar-git" "wayland bar (AUR git build)" "off"
  "wl-clipboard" "clipboard manager" "off"
  "wlogout" "logout menu" "off"
  "yad" "dialog box" "off"
  "yt-dlp" "video downloader" "off"
  "xarchiver" "Archive Manager" "off"
  "hypridle" "hyprland idling agent" "off"
  "hyprlock" "lockscreen" "off"
  "hyprpolkitagent" "hyprland polkit agent" "off"
  "xfce-polkit" "polkit agent" "off"
  "hyprland" "hyprland main package" "off"
=======
        "btop" "resource monitor" "off"
        "brightnessctl" "brightnessctl" "off"
        "cava" "Cross-platform Audio Visualizer" "off"
        "cliphist" "clipboard manager" "off"
        "fastfetch" "fastfetch" "off"
        "ffmpegthumbnailer" "FFmpeg Thumbnailer" "off"
        "grim" "screenshot tool" "off"
        "imagemagick" "Image manipulation tool" "off"
        "kitty" "kitty-terminal" "off"
        "kvantum" "QT apps theming" "off"
        "kvantum-qt5" "QT apps theming" "off"
        "qt5-declarative" "QT apps theming" "off"
        "qt5-quickcontrols2" "QT apps theming" "off"
        "mousepad" "simple text editor" "off"
        "mpv" "multi-media player" "off"
        "mpv-mpris" "mpv-plugin" "off"
        "network-manager-applet" "network-manager-applet" "off"
        "nvtop" "gpu resource monitor" "off"
        "nwg-displays" "display monitor configuration app" "off"
        "nwg-look" "gtk settings app" "off"
        "pamixer" "pamixer" "off"
        "pokemon-colorscripts-git" "terminal colorscripts" "off"
        "pavucontrol" "pavucontrol" "off"
        "playerctl" "playerctl" "off"
        "pyprland" "pyprland" "off"
        "qalculate-gtk" "calculator - QT" "off"
        "qt5ct" "qt5ct" "off"
        "qt6ct" "qt6ct" "off"
        "qt6-declarative" "QT apps theming" "off"
        "rofi" "rofi (app launcher)" "off"
        "slurp" "screenshot tool" "off"
        "swappy" "screenshot tool" "off"
        "swaync" "notification agent" "off"
        "awww" "wallpaper engine" "off"
        "thunar" "File Manager" "off"
        "thunar-archive-plugin" "Archive Plugin" "off"
        "thunar-volman" "Volume Management" "off"
        "tumbler" "Thumbnail Service" "off"
        "wallust" "color pallete generator" "off"
        "waybar" "wayland bar" "off"
        "wl-clipboard" "clipboard manager" "off"
        "wlogout" "logout menu" "off"
        "yad" "dialog box" "off"
        "yt-dlp" "video downloader" "off"
        "xarchiver" "Archive Manager" "off"
        "hypridle" "hyprland idling agent" "off"
        "hyprsunset" "hyprland night light" "off"
        "hyprland-guiutils" "hyprland gui utilities" "off"
        "hyprlock" "lockscreen" "off"
        "hyprpolkitagent" "hyprland polkit agent" "off"
        "xfce-polkit" "polkit agent" "off"
        "hyprland" "hyprland main package" "off"
>>>>>>> d670bd4 (Added qalculate-gtk to replace rofi calc)
)

# Define the list of directories to choose from (with options_command tags)
directories=(
  "btop" "btop configuration" "off"
  "cava" "cava configuration" "off"
  "fastfetch" "fastfetch configuration" "off"
  "hypr" "main hyprland configuration" "off"
  "kitty" "kitty terminal configuration" "off"
  "Kvantum" "Kvantum-manager configuration" "off"
  "qt5ct" "qt5ct configuration" "off"
  "qt6ct" "qt6ct configuration" "off"
  "rofi" "rofi configuration" "off"
  "swappy" "swappy (screenshot tool) configuration" "off"
  "swaync" "swaync (notification agent) configuration" "off"
  "Thunar" "Thunar file manager configuration" "off"
  "wallust" "wallust (color pallete) configuration" "off"
  "waybar" "waybar configuration" "off"
  "wlogout" "wlogout (logout menu) configuration" "off"
)

# Loop for package selection until user selects something or cancels
while true; do
  package_choices=$(whiptail --title "Select Packages to Uninstall" --checklist \
    "Select the packages you want to remove\nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 35 90 25 \
    "${packages[@]}" 3>&1 1>&2 2>&3)
  selection_status=$?

  if [ "$selection_status" -ne 0 ]; then
    note "Uninstall cancelled."
    exit 0
  fi

  if [ -z "$package_choices" ]; then
    note "No packages selected. Please select at least one package."
    continue
  fi

  printf '%s\n' "$package_choices" | tr -d '"' | tr ' ' '\n' | sed '/^$/d' >"$SELECTED_PACKAGES_FILE"
  step "Packages to remove: $package_choices"
  break
done

# Loop for directory selection until user selects something or cancels
while true; do
  dir_choices=$(whiptail --title "Select Directories to Remove" --checklist \
    "Select the directories you want to remove\nNOTE: This will remove configs from ~/.config\n\nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 90 18 \
    "${directories[@]}" 3>&1 1>&2 2>&3)
  selection_status=$?

  if [ "$selection_status" -ne 0 ]; then
    note "Uninstall cancelled."
    exit 0
  fi

  if [ -z "$dir_choices" ]; then
    note "No directories selected. Please select at least one directory."
    continue
  fi

  printf '%s\n' "$dir_choices" | tr -d '"' | tr ' ' '\n' | sed '/^$/d' >"$SELECTED_DIRECTORIES_FILE"
  step "Directories to remove: $dir_choices"
  break
done

selected_package_count=$(grep -c . "$SELECTED_PACKAGES_FILE" 2>/dev/null || true)
selected_directory_count=$(grep -c . "$SELECTED_DIRECTORIES_FILE" 2>/dev/null || true)

# First confirmation - show exactly how much will be removed
if ! whiptail --title "Warning" --yesno \
  "You are about to remove:\n\n  • ${selected_package_count} package(s)\n  • ${selected_directory_count} configuration director(ies) under ~/.config\n\nThis may leave your system unstable and unable to boot into Hyprland.\n\nAre you sure you want to proceed?" \
  15 80; then
  note "Uninstall cancelled."
  exit 0
fi

# Second confirmation - Final confirmation to proceed
if ! whiptail --title "Final Confirmation" --yesno \
  "Last chance.\n\n${selected_package_count} package(s) and ${selected_directory_count} directory group(s) will be removed.\n\nWARNING! This action is irreversible." \
  12 78; then
  note "Uninstall cancelled."
  exit 0
fi

printf "\n%.0s" {1..1}
section "Removing packages"

# Package removal, retried once: pacman can fail transiently if a file lock
# or a still-running session holds a package.
MAX_ATTEMPTS=2
attempt=0
while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
  attempt=$((attempt + 1))
  failed_packages=()
  remove_packages "$SELECTED_PACKAGES_FILE"

  still_installed=()
  while IFS= read -r package; do
    [ -n "$package" ] || continue
    if pacman -Qi "$package" &>/dev/null; then
      still_installed+=("$package")
    fi
  done <"$SELECTED_PACKAGES_FILE"

  if [ ${#still_installed[@]} -eq 0 ]; then
    break
  fi
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    warn "${#still_installed[@]} package(s) still installed; retrying..."
  fi
done

# Report what survived the retries instead of going quiet
if [ ${#still_installed[@]} -gt 0 ]; then
  error "Gave up after $MAX_ATTEMPTS attempts. These packages are still installed:"
  printf '  - %s\n' "${still_installed[@]}" | tee -a "$LOG"
fi

printf "\n%.0s" {1..1}
section "Removing local binaries"

for file in ags pokemon-colorscripts; do
  if [ -f "/usr/local/bin/$file" ]; then
    if sudo rm -- "/usr/local/bin/$file"; then
      ok "$file removed."
    else
      error "Failed to remove /usr/local/bin/$file"
      failed_local+=("/usr/local/bin/$file")
    fi
  fi
done

printf "\n%.0s" {1..1}
section "Removing configuration directories"

remove_directories "$SELECTED_DIRECTORIES_FILE"

printf "\n%.0s" {1..1}

exit_code=0
if [ ${#still_installed[@]} -gt 0 ] || [ ${#failed_dirs[@]} -gt 0 ] || [ ${#failed_local[@]} -gt 0 ]; then
  exit_code=1
  warn "Some items could not be removed:"
  for item in "${still_installed[@]}"; do printf ' - package: %s\n' "$item"; done
  for item in "${failed_dirs[@]}"; do printf ' - directory: %s\n' "$item"; done
  for item in "${failed_local[@]}"; do printf ' - file: %s\n' "$item"; done
fi

if [ "$exit_code" -eq 0 ]; then
  ok "Hyprland and related components have been uninstalled."
else
  warn "Uninstall finished with errors. See the items listed above and $LOG."
fi
note "It is recommended to reboot your system now."
printf "\n%.0s" {1..1}
exit "$exit_code"
