#!/usr/bin/env bash
# shellcheck disable=SC2034 # preset-backed option variables are read indirectly
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# https://github.com/LinuxBeginnings

# Shared color, icon and console helpers
# shellcheck source=install-scripts/colours.sh
source "$(dirname "$(readlink -f "$0")")/install-scripts/colours.sh"

# Put the cursor back if the run is interrupted while a spinner is active
trap restore_cursor EXIT
trap 'restore_cursor; exit 130' INT TERM

# Set a high-contrast whiptail theme unless the user already provided one
if [ -z "${NEWT_COLORS:-}" ]; then
  export NEWT_COLORS='
root=white,black
border=white,black
window=white,black
shadow=black,black
title=yellow,black
button=black,lightgray
actbutton=black,cyan
compactbutton=white,black
textbox=white,black
acttextbox=white,black
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,cyan
checkbox=white,black
actcheckbox=black,cyan
'
fi

usage() {
  cat <<EOF
Usage: $0 [options]

  --preset <file>  Pre-select menu options from a shell file
  --dry-run        Report what would run without changing the system
  -h, --help       Show this help and exit
EOF
}

# --preset <file> pre-fills the checklist, --dry-run only reports what would be
# done without installing, removing or writing anything
PRESET_FILE=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
  --preset)
    PRESET_FILE="${2:-}"
    if [ -z "$PRESET_FILE" ]; then
      printf '%s\n' "${ERROR} --preset needs a file name" >&2
      exit 1
    fi
    if [ ! -r "$PRESET_FILE" ]; then
      printf '%s\n' "${ERROR} Preset file not found or unreadable: $PRESET_FILE" >&2
      exit 1
    fi
    shift 2
    ;;
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf '%s\n' "${ERROR} Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

# A dry run must not write anything, log included
if [ "$DRY_RUN" -eq 1 ]; then
  LOG="/dev/null"
else
  if ! mkdir -p Install-Logs; then
    printf '%s\n' "${ERROR} Could not create the Install-Logs directory." >&2
    exit 1
  fi
  # Set the name of the log file to include the current date and time
  LOG="Install-Logs/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"
fi

# This installer only supports Arch and Arch-based distributions
if ! command -v pacman >/dev/null 2>&1; then
  printf '%s\n' "${ERROR} pacman not found. This installer targets Arch Linux." | tee -a "$LOG"
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  printf '%s\n' "${ERROR} sudo not found. Install sudo and run the installer again." | tee -a "$LOG"
  exit 1
fi

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
  printf '%s\n' "${ERROR} This script should ${WARNING}NOT${RESET} be executed as root!! Exiting......." | tee -a "$LOG"
  printf "\n%.0s" {1..2}
  exit 1
fi

# Check if PulseAudio package is installed
if pacman -Qq pulseaudio &>/dev/null; then
  printf '%s\n' "${ERROR} PulseAudio is detected as installed. Remove it first, or drop the 'pipewire.sh' step from install.sh." | tee -a "$LOG"
  printf "\n%.0s" {1..2}
  exit 1
fi

# Check if base-devel is installed
if pacman -Q base-devel &>/dev/null; then
  echo "base-devel is already installed."
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "${NOTE} base-devel would be installed."
else
  echo "$NOTE Install base-devel.........."

  if sudo pacman -S --noconfirm base-devel; then
    echo "👌 ${OK} base-devel has been installed successfully." | tee -a "$LOG"
  else
    echo "❌ $ERROR base-devel not found nor cannot be installed." | tee -a "$LOG"
    echo "$ACTION Please install base-devel manually before running this script... Exiting" | tee -a "$LOG"
    exit 1
  fi
fi

# install whiptails if detected not installed. Necessary for this version
if ! command -v whiptail >/dev/null; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "${NOTE} - whiptail is not installed. libnewt would be installed."
  else
    echo "${NOTE} - whiptail is not installed. Installing..." | tee -a "$LOG"
    sudo pacman -S --noconfirm libnewt
    printf "\n%.0s" {1..1}
  fi
fi

clear

print_banner "Install • 2026"
printf "\n%.0s" {1..1}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "${SKY_BLUE}[DRY-RUN]${RESET} Nothing will be installed, removed or written."
else
  # Welcome message using whiptail (for displaying information)
  whiptail --title "KooL Arch-Hyprland (2026) Install Script" \
    --msgbox "Welcome to KooL Arch-Hyprland (2026) Install Script!!!\n\n\
ATTENTION: Run a full system update and Reboot first !!! (Highly Recommended)\n\n\
NOTE: If you are installing on a VM, ensure to enable 3D acceleration else Hyprland may NOT start!" \
    15 80

  # Ask if the user wants to proceed
  if ! whiptail --title "Proceed with Installation?" \
    --yesno "Would you like to proceed?" 7 50; then
    echo -e "\n"
    echo "❌ ${INFO} You 🫵 chose ${YELLOW}NOT${RESET} to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
    echo -e "\n"
    exit 1
  fi
fi

echo "👌 ${OK} 🇵🇭 ${MAGENTA}KooL..${RESET} ${SKY_BLUE}lets continue with the installation...${RESET}" | tee -a "$LOG"

sleep 1
printf "\n%.0s" {1..1}

section "Prerequisites"

# install pciutils if detected not installed. Necessary for detecting GPU
if ! pacman -Qq pciutils &>/dev/null; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "${NOTE} - pciutils is not installed. It would be installed."
  else
    echo "${NOTE} - pciutils is not installed. Installing..." | tee -a "$LOG"
    if ! sudo pacman -S --noconfirm --needed pciutils; then
      warn "pciutils could not be installed. NVIDIA detection may be skipped."
    fi
    printf "\n%.0s" {1..1}
  fi
fi

# Path to the install-scripts directory
script_directory=install-scripts
WALLUST_STATUS_FILE="Install-Logs/.wallust-status"
FAILED_PACKAGES_FILE="Install-Logs/.failed-packages"
# Start every run with a clean failure report (a dry run keeps the last one)
if [ "$DRY_RUN" -eq 0 ]; then
  rm -f "$FAILED_PACKAGES_FILE"
fi
install_exit_code=0
wallust_setup_failed=0
dotfiles_paused_for_wallust=0
declare -a deferred_non_fatal_failures=()

# Run one install script, logging its start, result and duration
execute_script() {
  local script="$1"
  local script_path="$script_directory/$script"
  local started=$SECONDS status=0

  if [ ! -f "$script_path" ]; then
    error "Script '$script' not found in '$script_directory'."
    log_to_file "Missing script: $script_path"
    return 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s would run %s\n' "${SKY_BLUE}[DRY-RUN]${RESET}" "${YELLOW}$script_path${RESET}"
    return 0
  fi

  if ! chmod +x "$script_path" 2>/dev/null; then
    warn "Could not mark $script executable; running it with bash anyway."
  fi

  step "Running $script"
  bash "$script_path" || status=$?
  if [ "$status" -ne 0 ]; then
    error "$script exited with status $status after $((SECONDS - started))s."
    log_to_file "Script $script failed with exit status $status"
  else
    log_to_file "Script $script completed in $((SECONDS - started))s"
  fi
  return "$status"
}

## Default values for the options (will be overwritten by preset file if available)
gtk_themes="OFF"
bluetooth="OFF"
thunar="OFF"
sddm="OFF"
sddm_theme="OFF"
zsh="OFF"
pokemon="OFF"
rog="OFF"
dots="OFF"
ags="OFF"
input_group="OFF"
nvidia="OFF"
nouveau="OFF"

# Function to load preset file
load_preset() {
  if [ ! -f "$1" ]; then
    warn "Preset file not found: $1. Using default values."
    return 0
  fi
  echo "${OK} Loading preset: $1" | tee -a "$LOG"
  # shellcheck disable=SC1090
  source "$1"
  log_to_file "Loaded preset: $1"
}

# Load the preset given with --preset, if any
if [ -n "$PRESET_FILE" ]; then
  load_preset "$PRESET_FILE"
fi

# Normalize a preset value into the ON/OFF states whiptail's checklist expects
option_state() {
  local value="${!1}"
  case "${value,,}" in
  1 | on | yes | true | y) echo "ON" ;;
  *) echo "OFF" ;;
  esac
}

# Check if yay or paru is installed
section "AUR helper"
aur_helper=""
info "Checking for an installed AUR helper (yay or paru)..."
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
  echo "${CAT} - Neither yay nor paru found. Asking 🗣️ USER to select..."
  while true; do
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "${SKY_BLUE}[DRY-RUN]${RESET} an AUR helper (yay or paru) would be selected and installed."
      break
    fi

    if ! aur_helper=$(whiptail --title "Neither Yay nor Paru is installed" --checklist "Neither Yay nor Paru is installed. Choose one AUR.\n\nNOTE: Select only 1 AUR helper!\nINFO: spacebar to select" 12 60 2 \
      "yay" "AUR Helper yay" "OFF" \
      "paru" "AUR Helper paru" "OFF" \
      3>&1 1>&2 2>&3); then
      note "No AUR helper selected. Nothing was installed."
      exit 0
    fi

    if [ -z "$aur_helper" ]; then
      whiptail --title "Error" --msgbox "You must select at least one AUR helper to proceed." 10 60 2
      continue
    fi

    echo "${INFO} - You selected: $aur_helper as your AUR helper" | tee -a "$LOG"

    aur_helper="$(printf '%s' "$aur_helper" | tr -d '"' | tr -s ' ' | sed 's/^ //;s/ $//')"

    # Check if multiple helpers were selected
    if [[ $(printf '%s' "$aur_helper" | wc -w) -ne 1 ]]; then
      whiptail --title "Error" --msgbox "You must select exactly one AUR helper." 10 60 2
      continue
    else
      break
    fi
  done
else
  aur_helper="$(basename "$(command -v yay || command -v paru)")"
  note "AUR helper already installed ($aur_helper). Skipping selection."
fi

# List of services to check for active login managers
services=("gdm.service" "gdm3.service" "lightdm.service" "lxdm.service")
active_services=()

# Function to check if any login services are active
check_services_running() {
  active_services=() # Array to store active services
  command -v systemctl >/dev/null 2>&1 || return 1
  for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc"; then
      active_services+=("$svc")
    fi
  done

  if [ ${#active_services[@]} -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

if check_services_running; then
  active_list=$(printf "%s\n" "${active_services[@]}")

  # Display the active login manager(s) in the whiptail message box
  if [ "$DRY_RUN" -eq 0 ]; then
    whiptail --title "Active non-SDDM login manager(s) detected" \
      --msgbox "The following login manager(s) are active:\n\n$active_list\n\nIf you want to install SDDM and SDDM theme, stop and disable the active services above, reboot before running this script\n\nYour option to install SDDM and SDDM theme has now been removed\n\n- Ja " 23 80
  else
    printf "%s active login manager(s):\n%s\n" "${SKY_BLUE}[DRY-RUN]${RESET}" "$active_list"
  fi
fi

# NVIDIA needs pciutils, and absent lspci must not be treated as "no GPU"
has_nvidia_gpu() {
  local lspci_bin=""
  lspci_bin="$(command -v lspci || true)"
  [ -n "$lspci_bin" ] || return 1
  "$lspci_bin" 2>/dev/null | grep -qi nvidia
}

# Check if NVIDIA GPU is detected
nvidia_detected=false
if has_nvidia_gpu; then
  nvidia_detected=true
  if [ "$DRY_RUN" -eq 0 ]; then
    whiptail --title "NVIDIA GPU Detected" --msgbox "NVIDIA GPU detected in your system.\n\nNOTE: The script will install nvidia-dkms, nvidia-utils, and nvidia-settings if you chose to configure." 12 60
  else
    echo "${SKY_BLUE}[DRY-RUN]${RESET} NVIDIA GPU detected."
  fi
fi

# Initialize the options array for whiptail checklist
options_command=(
  whiptail --title "Select Options" --checklist "Choose options to install or configure\nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 85 20
)

# Add NVIDIA options if detected
if [ "$nvidia_detected" = "true" ]; then
  options_command+=(
    "nvidia" "Do you want script to configure NVIDIA GPU?" "$(option_state nvidia)"
    "nouveau" "Do you want Nouveau to be blacklisted?" "$(option_state nouveau)"
  )
fi

# Add 'input_group' option if user is not in input group
input_group_detected=false
if ! id -nG "$(id -un)" 2>/dev/null | tr ' ' '\n' | grep -qx input; then
  input_group_detected=true
  if [ "$DRY_RUN" -eq 0 ]; then
    whiptail --title "Input Group" --msgbox "You are not currently in the input group.\n\nAdding you to the input group might be necessary for the Waybar keyboard-state functionality." 12 60
  else
    echo "${SKY_BLUE}[DRY-RUN]${RESET} your user is not in the input group."
  fi
fi

# Add 'input_group' option if necessary
if [ "$input_group_detected" = "true" ]; then
  options_command+=(
    "input_group" "Add your USER to input group for some waybar functionality?" "$(option_state input_group)"
  )
fi

# Conditionally add SDDM and SDDM theme options if no active login manager is found
if ! check_services_running; then
  options_command+=(
    "sddm" "Install & configure SDDM login manager?" "$(option_state sddm)"
    "sddm_theme" "Download & Install Additional SDDM theme?" "$(option_state sddm_theme)"
  )
fi

# Add the remaining static options
options_command+=(
  "gtk_themes" "Install GTK themes? (required for Dark/Light function)" "$(option_state gtk_themes)"
  "bluetooth" "Do you want script to configure Bluetooth?" "$(option_state bluetooth)"
  "thunar" "Do you want Thunar file manager to be installed?" "$(option_state thunar)"
  "zsh" "Install zsh shell with Oh-My-Zsh?" "$(option_state zsh)"
  "pokemon" "Add Pokemon color scripts to your terminal?" "$(option_state pokemon)"
  "rog" "Are you installing on Asus ROG laptops?" "$(option_state rog)"
  "dots" "Download and install pre-configured KooL Hyprland dotfiles?" "$(option_state dots)"
  "ags" "Install AGS as an alternative desktop overview? (quickshell is installed)" "$(option_state ags)"
)

# Capture the selected options before the while loop starts
while true; do
  # A dry run has nobody to answer the checklist: take the preset values instead
  if [ "$DRY_RUN" -eq 1 ]; then
    selected_options=""
    for dry_option in nvidia nouveau input_group sddm sddm_theme gtk_themes bluetooth thunar zsh pokemon rog dots ags; do
      if [ "$(option_state "$dry_option")" == "ON" ]; then
        selected_options+="$dry_option "
      fi
    done
    selected_options="${selected_options% }"
    printf "%s options from preset: %s\n" "${SKY_BLUE}[DRY-RUN]${RESET}" "${selected_options:-none}"
    IFS=' ' read -r -a options <<<"$selected_options"
    break
  fi

  selected_options=$("${options_command[@]}" 3>&1 1>&2 2>&3)

  # Check if the user cancelled (1) or closed the dialog with ESC (255)
  selection_status=$?
  if [ "$selection_status" -ne 0 ]; then
    echo -e "\n"
    if [ "$selection_status" -eq 255 ]; then
      warn "Selection closed with ESC. Nothing was installed."
    else
      echo "❌ ${INFO} You 🫵 cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
    fi
    exit 0
  fi

  # If no option was selected, notify and restart the selection
  if [ -z "$selected_options" ]; then
    whiptail --title "Warning" --msgbox "No options were selected. Please select at least one option." 10 60
    continue # Return to selection if no options selected
  fi

  # Strip the quotes and trim spaces if necessary (sanitize the input)
  selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')

  # Convert selected options into an array (preserving spaces in values)
  IFS=' ' read -r -a options <<<"$selected_options"

  # Check if the "dots" option was selected
  dots_selected="OFF"
  for option in "${options[@]}"; do
    if [[ "$option" == "dots" ]]; then
      dots_selected="ON"
      break
    fi
  done

  # If "dots" is not selected, show a note and ask the user to proceed or return to choices
  if [[ "$dots_selected" == "OFF" ]]; then
    # Show a note about not selecting the "dots" option
    if ! whiptail --title "KooL Hyprland Dot Files" --yesno \
      "You have not selected to install the pre-configured KooLDots Hyprland dotfiles.\n\nKindly NOTE that if this a *new*  install, not an *upgrade*,  and you proceed without Dots, Hyprland will start with default vanilla Hyprland configuration and I won't be able to give you support.\n\nWould you like to continue install without KooL Hyprland Dots or return to choices/options?" \
      --yes-button "Continue" --no-button "Return" 15 90; then
      echo "🔙 Returning to options..." | tee -a "$LOG"
      continue
    else
      # User chose to continue
      echo "${INFO} ⚠️ Continuing WITHOUT the dotfiles installation..." | tee -a "$LOG"
      printf "\n%.0s" {1..1}
    fi
  fi

  # Prepare the confirmation message
  section "Selected options"
  confirm_message="You have selected the following options:\n\n"
  for option in "${options[@]}"; do
    confirm_message+=" - $option\n"
  done
  confirm_message+="\nAre you happy with these choices?"

  # Confirmation prompt
  if ! whiptail --title "Confirm Your Choices" --yesno "$(printf "%s" "$confirm_message")" 25 80; then
    echo -e "\n"
    echo "❌ ${SKY_BLUE}You're not 🫵 happy${RESET}. ${YELLOW}Returning to options...${RESET}" | tee -a "$LOG"
    continue
  fi

  echo "👌 ${OK} You confirmed your choices. Proceeding with ${SKY_BLUE}KooL 🇵🇭 Hyprland Installation...${RESET}" | tee -a "$LOG"
  break
done

printf "\n%.0s" {1..1}

section "Base system setup"

# Ensuring base-devel is installed
execute_script "00-base.sh" || {
  echo "${ERROR:-[ERROR]} Base devel installation failed" | tee -a "$LOG"
  exit 1
}
sleep 1
execute_script "pacman.sh" || {
  echo "${ERROR:-[ERROR]} Pacman setup failed" | tee -a "$LOG"
  exit 1
}
sleep 1

# Execute AUR helper script after other installations if applicable
if [ "$aur_helper" == "paru" ]; then
  execute_script "paru.sh" || {
    echo "${ERROR:-[ERROR]} AUR helper (paru) installation failed" | tee -a "$LOG"
    exit 1
  }
elif [ "$aur_helper" == "yay" ]; then
  execute_script "yay.sh" || {
    echo "${ERROR:-[ERROR]} AUR helper (yay) installation failed" | tee -a "$LOG"
    exit 1
  }
fi

sleep 1

section "Hyprland packages"

# Run the Hyprland related scripts
echo "${INFO} Installing ${SKY_BLUE}KooL Hyprland additional packages...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "01-hypr-pkgs.sh" || {
  echo "${ERROR:-[ERROR]} Hyprland packages installation failed" | tee -a "$LOG"
  exit 1
}
sleep 1

if [ "$DRY_RUN" -eq 1 ]; then
  # The marker belongs to an earlier run, a dry run has no wallust result yet
  wallust_setup_failed=0
elif [ -f "$WALLUST_STATUS_FILE" ]; then
  wallust_status="$(tr -d '[:space:]' <"$WALLUST_STATUS_FILE")"
  if [ "$wallust_status" = "failed" ]; then
    wallust_setup_failed=1
    deferred_non_fatal_failures+=("wallust compatibility setup failed (theming may be incomplete)")
    echo "${WARN} wallust compatibility setup failed. Continuing with the remaining installation." | tee -a "$LOG"
  fi
else
  wallust_setup_failed=1
  deferred_non_fatal_failures+=("wallust compatibility status could not be determined")
  echo "${WARN} wallust status marker is missing. Continuing, but dotfiles will be paused if selected." | tee -a "$LOG"
fi
sleep 1
execute_script "polkit-setup.sh" || {
  echo "${ERROR:-[ERROR]} Polkit setup failed" | tee -a "$LOG"
  exit 1
}

echo "${INFO} Installing ${SKY_BLUE}pipewire and pipewire-audio...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "pipewire.sh" || {
  echo "${ERROR:-[ERROR]} Pipewire installation failed" | tee -a "$LOG"
  exit 1
}

echo "${INFO} Installing ${SKY_BLUE}necessary fonts...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "fonts.sh" || {
  echo "${ERROR:-[ERROR]} Fonts installation failed" | tee -a "$LOG"
  exit 1
}

echo "${INFO} Installing ${SKY_BLUE}Hyprland...${RESET}"
sleep 1
execute_script "hyprland.sh" || {
  echo "${ERROR:-[ERROR]} Hyprland installation failed" | tee -a "$LOG"
  exit 1
}

# quickshell is a hard dependency of the dots and is installed with the
# packages in 01-hypr-pkgs.sh. xdg-desktop-portal-hyprland is not optional
# either; neither is offered as a menu choice.
echo "${INFO} Installing ${SKY_BLUE}xdg-desktop-portal-hyprland...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "xdph.sh" || {
  echo "${ERROR:-[ERROR]} xdg-desktop-portal-hyprland installation failed" | tee -a "$LOG"
  exit 1
}

section "Optional components"

# Clean up the selected options (remove quotes and trim spaces)
selected_options=$(printf '%s' "$selected_options" | tr -d '"' | tr -s ' ')  # Convert selected options into an array (splitting by spaces)
  IFS=' ' read -r -a options <<<"$selected_options"

# Loop through selected options
for option in "${options[@]}"; do
  case "$option" in
  sddm)
    if check_services_running; then
      active_list=$(printf "%s\n" "${active_services[@]}")
      if [ "$DRY_RUN" -eq 0 ]; then
        whiptail --title "Error" --msgbox "One of the following login services is running:\n$active_list\n\nPlease stop & disable it or DO not choose SDDM.\n\nSDDM installation will be skipped." 12 60
      fi
      echo "${WARN} Skipping SDDM: stop and disable the login manager(s) above, then rerun the installer with the SDDM option." | tee -a "$LOG"
    else
      echo "${INFO} Installing and configuring ${SKY_BLUE}SDDM...${RESET}" | tee -a "$LOG"
      execute_script "sddm.sh"
    fi
    ;;
  nvidia)
    echo "${INFO} Configuring ${SKY_BLUE}nvidia stuff${RESET}" | tee -a "$LOG"
    execute_script "nvidia.sh"
    ;;
  nouveau)
    echo "${INFO} blacklisting ${SKY_BLUE}nouveau${RESET}" | tee -a "$LOG"
    execute_script "nvidia_nouveau.sh" || warn "nouveau blacklist setup failed; check the log."
    ;;
  gtk_themes)
    echo "${INFO} Installing ${SKY_BLUE}GTK themes...${RESET}" | tee -a "$LOG"
    execute_script "gtk_themes.sh"
    ;;
  input_group)
    echo "${INFO} Adding user into ${SKY_BLUE}input group...${RESET}" | tee -a "$LOG"
    execute_script "InputGroup.sh"
    ;;
  bluetooth)
    echo "${INFO} Configuring ${SKY_BLUE}Bluetooth...${RESET}" | tee -a "$LOG"
    execute_script "bluetooth.sh"
    ;;
  thunar)
    echo "${INFO} Installing ${SKY_BLUE}Thunar file manager...${RESET}" | tee -a "$LOG"
    execute_script "thunar.sh"
    execute_script "thunar_default.sh"
    ;;
  sddm_theme)
    echo "${INFO} Downloading & Installing ${SKY_BLUE}Additional SDDM theme...${RESET}" | tee -a "$LOG"
    execute_script "sddm_theme.sh"
    ;;
  zsh)
    echo "${INFO} Installing ${SKY_BLUE}zsh with Oh-My-Zsh...${RESET}" | tee -a "$LOG"
    execute_script "zsh.sh"
    ;;
  pokemon)
    echo "${INFO} Adding ${SKY_BLUE}Pokemon color scripts to terminal...${RESET}" | tee -a "$LOG"
    execute_script "zsh_pokemon.sh"
    ;;
  rog)
    echo "${INFO} Installing ${SKY_BLUE}ROG laptop packages...${RESET}" | tee -a "$LOG"
    execute_script "rog.sh"
    ;;
  ags)
    echo "${INFO} Installing ${SKY_BLUE}AGS (Aylur's GTK Shell) desktop overview...${RESET}" | tee -a "$LOG"
    execute_script "ags.sh" || warn "AGS installation failed; the quickshell overview remains available."
    ;;
  dots)
    if [ "$wallust_setup_failed" -ne 0 ]; then
      dotfiles_paused_for_wallust=1
      deferred_non_fatal_failures+=("dotfiles installation paused because wallust setup failed")
      echo "${WARN} Dotfiles installation paused because wallust compatibility setup failed." | tee -a "$LOG"
      if command -v whiptail >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
        whiptail --title "Dotfiles Paused" --msgbox "wallust compatibility setup failed earlier.\n\nDotfiles installation has been paused to avoid an incomplete theming setup.\n\nFix wallust first, then rerun with only the dots option or run install-scripts/dotfiles-main.sh manually." 14 90
      fi
      continue
    fi
    echo "${INFO} Installing pre-configured ${SKY_BLUE}KooL Hyprland dotfiles...${RESET}" | tee -a "$LOG"
    execute_script "dotfiles-main.sh" || {
      echo "${ERROR:-[ERROR]} Dotfiles installation failed" | tee -a "$LOG"
      exit 1
    }
    ;;
  *)
    echo "Unknown option: $option" | tee -a "$LOG"
    ;;
  esac
done

sleep 1

clear

section "Final verification"

# final check essential packages if it is installed
execute_script "02-Final-Check.sh"

if [ "$DRY_RUN" -eq 1 ]; then
  printf "\n%s Dry run finished. Nothing was installed, removed or written.\n" "${SKY_BLUE}[DRY-RUN]${RESET}"
  exit 0
fi
if [ ${#deferred_non_fatal_failures[@]} -gt 0 ]; then
  printf "\n%s - Installation completed with non-fatal issues:\n" "${WARN}" | tee -a "$LOG"
  for issue in "${deferred_non_fatal_failures[@]}"; do
    printf " - %s\n" "$issue" | tee -a "$LOG"
  done
  if [ "$dotfiles_paused_for_wallust" -ne 0 ]; then
    printf "%s Re-run after fixing wallust to install KooL dotfiles.\n" "${NOTE}" | tee -a "$LOG"
  fi
fi

# Packages that failed to install were recorded by Global_functions.sh
if [ -s "$FAILED_PACKAGES_FILE" ]; then
  mapfile -t failed_packages < <(sort -u "$FAILED_PACKAGES_FILE")
  printf "\n%s %d package(s) failed to install during this run:\n" "${ERROR}" "${#failed_packages[@]}" | tee -a "$LOG"
  for failed_pkg in "${failed_packages[@]}"; do
    printf "  - %s\n" "$failed_pkg" | tee -a "$LOG"
  done
  printf "%s Install them manually, or fix the cause (details in %s) and rerun the installer. Exiting with an error status.\n" "${NOTE}" "$LOG" | tee -a "$LOG"
  install_exit_code=1
fi

printf "\n%.0s" {1..1}

# Check if hyprland or hyprland-git is installed
if pacman -Q hyprland &>/dev/null || pacman -Q hyprland-git &>/dev/null; then
  printf '\n %s 👌 Hyprland is installed. However, some essential packages may not be installed. Please see above!\n' "$OK"
  printf '\n%s Ignore this message if it states %sAll essential packages%s are installed as per above\n' "$CAT" "$YELLOW" "$RESET"
  sleep 2
  printf "\n%.0s" {1..2}

  printf '%sThank you%s 🫰 for using 🇵🇭 %sKooL Hyprland Dots%s. %sEnjoy and have a good day!%s\n' "$SKY_BLUE" "$RESET" "$MAGENTA" "$RESET" "$YELLOW" "$RESET"
  printf "\n%.0s" {1..2}

  printf '\n%s You can start Hyprland by typing %sstart-hyprland%s (if SDDM is not installed).\n' "$NOTE" "$SKY_BLUE" "$RESET"
  printf '\n%s However, it is %shighly recommended to reboot%s your system.\n\n' "$NOTE" "$YELLOW" "$RESET"

  while true; do
    printf '%s Would you like to reboot now? (y/n): ' "$CAT"
    read -r HYP || HYP="n"
    HYP=$(echo "$HYP" | tr '[:upper:]' '[:lower:]')

    if [[ "$HYP" == "y" || "$HYP" == "yes" ]]; then
      echo "${INFO} Rebooting now..."
      systemctl reboot
      break
    elif [[ "$HYP" == "n" || "$HYP" == "no" ]]; then
      echo "👌 ${OK} You chose NOT to reboot"
      printf "\n%.0s" {1..1}
      # Check if NVIDIA GPU is present
      if has_nvidia_gpu; then
        echo "${INFO} HOWEVER ${YELLOW}NVIDIA GPU${RESET} detected. Reminder that you must REBOOT your SYSTEM..."
        printf "\n%.0s" {1..1}
      fi
      break
    else
      echo "${WARN} Invalid response. Please answer with 'y' or 'n'."
    fi
  done
else
  # Print error message if neither package is installed
  printf "\n${WARN} Hyprland is NOT installed. Check the 00_CHECK-*_installed.log file and the other logs in Install-Logs/."
  printf "\n%.0s" {1..3}
  exit 1
fi

printf "\n%.0s" {1..2}

# Non-zero when packages failed to install, so wrappers/auto-install can react
exit "$install_exit_code"
