#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Nvidia Stuffs #

nvidia_pkg=(
  nvidia-dkms
  nvidia-settings
  nvidia-utils
  libva
  libva-nvidia-driver
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_nvidia.log"


# nvidia stuff
printf "${YELLOW} Checking for other hyprland packages and remove if any..${RESET}\n"
if pacman -Qs hyprland > /dev/null; then
  printf "${YELLOW} Hyprland detected. removing to install Hyprland from official repo...${RESET}\n"
    for hyprnvi in hyprland-git hyprland-nvidia hyprland-nvidia-git hyprland-nvidia-hidpi-git; do
    sudo pacman -R --noconfirm "$hyprnvi" 2>/dev/null | tee -a "$LOG" || true
    done
fi

# Install additional Nvidia packages
printf "${YELLOW} Installing ${SKY_BLUE}Nvidia Packages and Linux headers${RESET}...\n"
kernel_pkgbases=()
for pkgbase_file in /usr/lib/modules/*/pkgbase; do
  [ -f "$pkgbase_file" ] || continue
  kernel_pkgbases+=("$(cat "$pkgbase_file")")
done
if [ ${#kernel_pkgbases[@]} -eq 0 ]; then
  warn "No kernel found in /usr/lib/modules/*/pkgbase; kernel headers were not installed."
fi
# Kernel headers once per installed kernel, then the Nvidia packages once
for krnl in "${kernel_pkgbases[@]}"; do
  install_package "${krnl}-headers" "$LOG"
done
for NVIDIA in "${nvidia_pkg[@]}"; do
  install_package "$NVIDIA" "$LOG"
done

# Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
if grep -qE '^MODULES=.*nvidia_drm' "$MKINITCPIO_CONF"; then
  note "Nvidia modules are already included in $MKINITCPIO_CONF."
else
  MKINITCPIO_BACKUP="$MKINITCPIO_CONF.bak-$(date +%Y%m%d-%H%M%S)"
  if sudo cp -a "$MKINITCPIO_CONF" "$MKINITCPIO_BACKUP"; then
    info "Backed up $MKINITCPIO_CONF to $MKINITCPIO_BACKUP"
  else
    warn "Could not back up $MKINITCPIO_CONF; continuing."
  fi

  # shellcheck disable=SC2024 # the log file is owned by the invoking user
  if ! sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_CONF" >>"$LOG" 2>&1; then
    warn "Could not edit $MKINITCPIO_CONF."
  fi

  if grep -qE '^MODULES=.*nvidia_drm' "$MKINITCPIO_CONF"; then
    ok "Nvidia modules added to $MKINITCPIO_CONF."
  else
    warn "The Nvidia modules were not added to $MKINITCPIO_CONF. Add them manually."
  fi
fi

printf "\n%.0s" {1..1}
printf "${INFO} Rebuilding ${YELLOW}Initramfs${RESET}...\n" 2>&1 | tee -a "$LOG"
# shellcheck disable=SC2024 # the log file is owned by the invoking user
if ! sudo mkinitcpio -P >>"$LOG" 2>&1; then
  warn "mkinitcpio failed. Check $LOG before rebooting."
else
  ok "Initramfs rebuilt."
fi

printf "\n%.0s" {1..1}

# Additional Nvidia steps
NVEA="/etc/modprobe.d/nvidia.conf"
if [ -f "$NVEA" ] && grep -q 'nvidia_drm' "$NVEA"; then
  note "nvidia_drm modeset/fbdev options are already present in $NVEA."
else
  step "Adding nvidia_drm options to $NVEA"
  # shellcheck disable=SC2024 # the log file is owned by the invoking user
  printf '%s\n' "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a "$NVEA" >>"$LOG" 2>&1 || warn "Could not write to $NVEA."
  if grep -q 'nvidia_drm' "$NVEA" 2>/dev/null; then
    ok "nvidia_drm options written to $NVEA."
  else
    warn "Could not write to $NVEA."
  fi
fi

# Additional for GRUB users
if [ -f /etc/default/grub ]; then
    printf "${INFO} ${YELLOW}GRUB${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"

    GRUB_BACKUP="/etc/default/grub.bak-$(date +%Y%m%d-%H%M%S)"
    if sudo cp -a /etc/default/grub "$GRUB_BACKUP"; then
        info "Backed up /etc/default/grub to $GRUB_BACKUP"
    else
        warn "Could not back up /etc/default/grub."
    fi
    
    # Check if nvidia-drm.modeset=1 is present
    if ! sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
        printf "${OK} nvidia-drm.modeset=1 added to /etc/default/grub\n" 2>&1 | tee -a "$LOG"
    fi

    # Check if nvidia_drm.fbdev=1 is present
    if ! sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
        printf "${OK} nvidia_drm.fbdev=1 added to /etc/default/grub\n" 2>&1 | tee -a "$LOG"
    fi

    # Regenerate GRUB configuration 
    if sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub || sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
       # shellcheck disable=SC2024 # the log file is owned by the invoking user
       if sudo grub-mkconfig -o /boot/grub/grub.cfg >>"$LOG" 2>&1; then
           printf "${INFO} ${YELLOW}GRUB${RESET} configuration regenerated\n" 2>&1 | tee -a "$LOG"
       else
           warn "grub-mkconfig failed. Check $LOG before rebooting."
       fi
    fi
  
    printf "${OK} Additional steps for ${YELLOW}GRUB${RESET} completed\n" 2>&1 | tee -a "$LOG"
fi

# Additional for systemd-boot users
if [ -f /boot/loader/loader.conf ]; then
    printf "${INFO} ${YELLOW}systemd-boot${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"
  
    backup_count=0
    conf_count=0
    if [ -d /boot/loader/entries ]; then
        backup_count=$(find /boot/loader/entries -type f -name "*.conf.bak" | wc -l)
        conf_count=$(find /boot/loader/entries -type f -name "*.conf" | wc -l)
    fi

    if [ "$conf_count" -eq 0 ]; then
        warn "No systemd-boot entries found in /boot/loader/entries."
    elif [ "$backup_count" -ne "$conf_count" ]; then
        find /boot/loader/entries/ -type f -name "*.conf" | while read imgconf; do
            # Backup conf
            sudo cp "$imgconf" "$imgconf.bak"
            printf "${INFO} Backup created for systemd-boot loader: %s\n" "$imgconf" 2>&1 | tee -a "$LOG"
            
            # Clean up options and update with NVIDIA settings
            sdopt=$(grep -w "^options" "$imgconf" | sed 's/\b nvidia-drm.modeset=[^ ]*\b//g' | sed 's/\b nvidia_drm.fbdev=[^ ]*\b//g')
            sudo sed -i "/^options/c${sdopt} nvidia-drm.modeset=1 nvidia_drm.fbdev=1" "$imgconf" 2>&1 | tee -a "$LOG"
        done

        printf "${OK} Additional steps for ${YELLOW}systemd-boot${RESET} completed\n" 2>&1 | tee -a "$LOG"
    else
        printf "${NOTE} ${YELLOW}systemd-boot${RESET} is already configured...\n" 2>&1 | tee -a "$LOG"
    fi
fi

printf "\n%.0s" {1..2} 