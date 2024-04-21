#!/bin/bash

## Version 0.2
## License: GPL
## Copyright: (c) 2023
## Dependenices: rsync

## ALL THE BORING STUFF

# Global Variables for ANSI color
# Color variables
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
blue='\033[0;34m'
purple='\033[0;35m'
brown='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m' # No Color

#Checking if dependancies are installed
deps=("rsync")

for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null; then
    echo -e "${red}CRITCAL ERROR!!: $dep is not installed or not in the PATH${reset}"
    exit 1
fi
done

# Script splash
echo -e "${purple}"
echo -e "     ___    ____  ________  _______    ________     ____       _______  ___   ________ "
echo -e "    /   |  / __ \/ ____/ / / /  _/ |  / / ____/    / __ \     / ___/\ \/ / | / / ____/ "
echo -e "   / /| | / /_/ / /   / /_/ // / | | / / __/______/ /_/ /_____\__ \  \  /  |/ / /      "
echo -e "  / ___ |/ _, _/ /___/ __  // /  | |/ / /__/_____/ _, _/_____/__/ /  / / /|  / /___    "
echo -e " /_/  |_/_/ |_|\____/_/ /_/___/  |___/_____/    /_/ |_|     /____/  /_/_/ |_/\____/    "
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

