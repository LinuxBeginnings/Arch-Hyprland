#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# zsh and oh my zsh#

zsh_pkg=(
  lsd
  mercurial
  zsh
  zsh-completions
)

zsh_pkg2=(
  fzf
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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_zsh.log"

# Installing core zsh packages
printf "\n%s - Installing ${SKY_BLUE}zsh packages${RESET} .... \n" "${NOTE}"
for ZSH in "${zsh_pkg[@]}"; do
  install_package "$ZSH" "$LOG"
done 



# Check if the zsh-completions directory exists
if [ -d "zsh-completions" ]; then
    rm -rf zsh-completions
fi

# Install Oh My Zsh, plugins, and set zsh as default shell
if command -v zsh >/dev/null; then
  printf "${NOTE} Installing ${SKY_BLUE}Oh My Zsh and plugins${RESET} ...\n"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then  
    omz_installer="$(mktemp)"
    if ! curl -fsSL -o "$omz_installer" https://install.ohmyz.sh; then
      rm -f "$omz_installer"
      echo "${ERROR} Could not download the Oh My Zsh installer. Check your connection." | tee -a "$LOG"
      exit 1
    fi
    if ! sh "$omz_installer" "" --unattended; then
      rm -f "$omz_installer"
      echo "${ERROR} Oh My Zsh installation failed." | tee -a "$LOG"
      exit 1
    fi
    rm -f "$omz_installer"  	       
  else
    echo "${INFO} Directory .oh-my-zsh already exists. Skipping re-installation." 2>&1 | tee -a "$LOG"
  fi
  
  # Check if the directories exist before cloning the repositories
  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      if ! git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"; then
        echo "${WARN} Could not install zsh-autosuggestions." | tee -a "$LOG"
      fi 
  else
      echo "${INFO} Directory zsh-autosuggestions already exists. Cloning Skipped." 2>&1 | tee -a "$LOG"
  fi

  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      if ! git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"; then
        echo "${WARN} Could not install zsh-syntax-highlighting." | tee -a "$LOG"
      fi 
  else
      echo "${INFO} Directory zsh-syntax-highlighting already exists. Cloning Skipped." 2>&1 | tee -a "$LOG"
  fi
  
  # Check if ~/.zshrc and .zprofile exists, create a backup, and copy the new configuration
  # cp -b creates "file~" backups; use explicit timestamped names instead
  backup_stamp="$(date +%Y%m%d-%H%M%S)"
  for dotfile in .zshrc .zprofile; do
    if [ -f "$HOME/$dotfile" ]; then
      if cp -f -- "$HOME/$dotfile" "$HOME/$dotfile.bak-$backup_stamp"; then
        echo "${INFO} Backed up $dotfile to $dotfile.bak-$backup_stamp" | tee -a "$LOG"
      else
        echo "${WARN} Could not back up $dotfile; continuing." | tee -a "$LOG"
      fi
    fi
  done
  
  # Copying the preconfigured zsh themes and profile
  for asset in .zshrc .zprofile; do
    if [ ! -f "assets/$asset" ]; then
      echo "${WARN} Missing assets/$asset; keeping your existing $asset." | tee -a "$LOG"
      continue
    fi
    if ! cp -f "assets/$asset" "$HOME/$asset"; then
      echo "${ERROR} Failed to copy assets/$asset." | tee -a "$LOG"
      exit 1
    fi
  done

  # Check the login shell from the passwd database: $SHELL can be stale
  zsh_bin="$(command -v zsh)"
  current_login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [ "$current_login_shell" != "$zsh_bin" ]; then
    printf "${NOTE} Changing default shell to ${MAGENTA}zsh${RESET}..."
    printf "\n%.0s" {1..2}

    # chsh can fail for reasons other than a wrong password, so bound the retries
    attempts=0
    until chsh -s "$zsh_bin"; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 3 ]; then
        echo "${WARN} Could not change the login shell after 3 attempts. Run: chsh -s $zsh_bin" | tee -a "$LOG"
        break
      fi
      echo "${ERROR} Authentication failed. Please enter the correct password." 2>&1 | tee -a "$LOG"
      sleep 1
    done

    if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$zsh_bin" ]; then
      printf "${INFO} Shell changed successfully to ${MAGENTA}zsh${RESET}" 2>&1 | tee -a "$LOG"
    fi
  else
    echo "${NOTE} Your shell is already set to ${MAGENTA}zsh${RESET}."
  fi
  
fi

# Installing core zsh packages
printf "\n%s - Installing ${SKY_BLUE}fzf${RESET} .... \n" "${NOTE}"
for ZSH2 in "${zsh_pkg2[@]}"; do
  install_package "$ZSH2" "$LOG"
done

# copy additional oh-my-zsh themes from assets
if [ -d "$HOME/.oh-my-zsh/themes" ] && [ -d "assets/add_zsh_theme" ]; then
    if ! cp -r assets/add_zsh_theme/* "$HOME/.oh-my-zsh/themes/" >>"$LOG" 2>&1; then
        echo "${WARN} Could not copy the additional zsh themes." | tee -a "$LOG"
    fi
fi

printf "\n%.0s" {1..2}
