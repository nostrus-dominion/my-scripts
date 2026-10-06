#!/bin/bash

## Version 0.2
## License: GPL
## Copyright: (c) 2023

set -euo pipefail

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check
dependencies=("rsync" "ssh" "mkdir")
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

# Script splash
echo -e "${orange}"
cat << 'SPLASH'
     ___    ____  ________  _______    ________     ____       _______  ___   ________ 
    /   |  / __ \/ ____/ / / /  _/ |  / / ____/    / __ \     / ___/\ \/ / | / / ____/ 
   / /| | / /_/ / /   / /_/ // / | | / / __/______/ /_/ /_____\__ \  \  /  |/ / /      
  / ___ |/ _, _/ /___/ __  // /  | |/ / /__/_____/ _, _/_____/__/ /  / / /|  / /___    
 /_/  |_/_/ |_|\____/_/ /_/___/  |___/_____/    /_/ |_|     /____/  /_/_/ |_/\____/ 

SPLASH
echo -e "${reset}"

# Get user input for source host and directory
read -p $"Enter source host (user@source_host): " source_host
echo""
read -p $"Enter source directory path: " source_dir

# Use localhost as the destination host
destination_host="localhost"
read -p "Enter destination directory path: " destination_dir

# Ensure that the destination directory exists
mkdir -p "$destination_dir"

# Use rsync to copy files from source to destination
rsync -av --progress "$source_host":"$source_dir" "$destination_dir"

# Check if rsync was successful (exit code 0)
if [ $? -eq 0 ]; then
  echo "File transfer successful. Do you want to remove files from the source host? (y/n)"
  read -r confirmation

  if [ "$confirmation" == "y" ]; then
    echo "Removing files from the source host..."

    # Remove files from the source host
    ssh "$source_host" "rm -r '$source_dir/*'"

    echo "Files removed from the source host."
  else
    echo "Files were not removed from the source host. You chose not to delete them."
  fi
else
  echo "Error: File transfer failed. Please check the rsync command for errors."
fi
