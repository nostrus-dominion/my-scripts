#!/bin/bash

# Dependency check.
dependencies=("find" "rm" "sleep")
missing_dependencies=()
for dependency in "${dependencies[@]}"; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    missing_dependencies+=("$dependency")
  fi
done
if ((${#missing_dependencies[@]})); then
  for dependency in "${missing_dependencies[@]}"; do
    printf 'ERROR: Required command "%s" is not installed or not in PATH.\n' "$dependency" >&2
  done
  exit 1
fi


## Verision 2.1
## V1 Created 2018-07-19
## License: Open Source GPL
## Copyright: (c) 2023

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Script splash

echo -e "${orange}"
cat << 'SPLASH'
  _____   ______  _       ______  _______  ______  _____   
 |  __ \ |  ____|| |     |  ____||__   __||  ____||  __ \  
 | |  | || |__   | |     | |__      | |   | |__   | |__) | 
 | |  | ||  __|  | |     |  __|     | |   |  __|  |  _  /  
 | |__| || |____ | |____ | |____    | |   | |____ | | \ \ 
 |_____/ |______||______||______|   |_|   |______||_|  \_\
SPLASH
echo -e "${reset}" 
echo -e "         ${red}WARNING!! THESE DELETIONS ARE PERMANENT!!${reset}"
echo -e "         ${red}DO NOT USE THIS UNLESS YOU'RE 100% SURE!!${reset}"
echo ""

while true; do
  read -p "Are you sure you want to continue? (y/n): " response
  case $response in
    [Yy]*) break ;;
    [Nn]*) exit 1 ;;
    *) echo "Please answer yes (y) or no (n)." ;;
  esac
done

while true; do
  read -r -p "Enter the file extension to delete (e.g. txt): " file_extension

  matching_files=$(find . -iname "*.$file_extension")

  if [[ "$matching_files" ]]; then
    echo ""
    echo -e "${yellow}The following files will be deleted:${reset}"
    echo -e "${matching_files}"
    echo ""

    read -p "Are you SURE you want to continue with deletion? (y/n):" response
    case $response in
      [Yy]*) break ;;
      [Nn]*) exit 1 ;;
      *) echo "You must answer yes (y) or no (n)." ;;
    esac
  else
    echo -e "${red}Error! No files found with this file extension!${reset}"
    echo -e "${red}Please enter a valid file extension!${reset}"
  fi
done

echo
echo "Last chance to exit script."
echo "10 second countdown to [CTRL-C] to cancel"

for i in {10..1}; do
  if [ "$i" -ge 6 ]; then
    echo -ne "${green}$i. ${reset}"
  elif [ "$i" -ge 3 ]; then
    echo -ne "${yellow}$i. ${reset}"
  else
    echo -ne "${red}$i. ${reset}"
  fi
  sleep 1
done

find . -name "*.$file_extension" -exec rm -rf {} \;

echo ""
echo "All .$file_extension files have been deleted!"
echo "Hope you were sure!"
