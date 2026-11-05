#!/bin/bash
# shellcheck disable=SC2034 # color variables are used throughout the script
# /* ---- 💫 https://github.com/LinuxBeginnings 💫 ---- */  #

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA=$(tput setaf 5)
WARNING=$(tput setaf 1)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { echo -e "${ERROR} Cannot enter $SCRIPT_DIR"; exit 1; }

# Make all scripts in the scripts directory executable
echo -e "${INFO} Making all files in the ${BLUE}scripts${RESET} directory executable..."
if ! compgen -G "./scripts/*" >/dev/null; then
    echo -e "${ERROR} No scripts found in ./scripts"
    exit 1
fi
chmod +x ./scripts/*

printf "\n%.0s" {1..2}

while true; do
    echo -e "${BLUE}   Please choose an option:${RESET}"
    echo -e "${YELLOW} -- 1 - Install non-git Hyprland version${RESET}"
    echo -e "${YELLOW} -- 2 - Install git Hyprland version${RESET}"
    echo -e "${YELLOW} -- 3 - Update Hyprland-git packages${RESET}"
    echo -e "${MAGENTA} -- 4 - Quit${RESET}"

    read -r -p "${CAT} Enter your choice [1, 2, 3 or 4]: " choice

    case $choice in
        1)
            printf "\n${OK} You chose ${BLUE}non-git version of Hyprland${RESET}....... executing...\n"
            echo -e "${YELLOW} Uninstalling some hyprland packages first...${RESET}"
            ./scripts/uninstall.sh &&
            ./scripts/install-hyprland.sh
            break
            ;;
        2)
            printf "\n${OK} You chose ${BLUE}git version of Hyprland${RESET}....... executing...\n"
            echo -e "${YELLOW} Uninstalling some hyprland packages....${RESET}"
            ./scripts/uninstall.sh &&
            ./scripts/install-hyprland-git.sh
            break
            ;;
        3)
            printf "\n${OK} You chose ${BLUE} to update Hyprland-git packages${RESET}....... executing...\n"
            ./scripts/install-hyprland-git.sh
            break
            ;;
        4)
            echo -e "${MAGENTA} You have cancel it. Good Bye!!...${RESET}"
            printf "\n%.0s" {1..2}
            break
            ;;
        *)
            echo -e "\n${WARNING} There are only 4 Choices!!!! 1 2 3 or 4. Enter 1, 2, 3, or 4 only.${RESET}"
            ;;
    esac
    
done
