#!/bin/bash

## Version 1.5
## License: Open Source GPL
## Copyright: (c) 2023

## ALL THE BORING STUFF

# Global color variables
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

# Script Splash
echo -e "${brown}"
echo -e "-----------------------------------------"
echo -e "|    File Extension Converter Script    |"
echo -e "-----------------------------------------"
echo -e "This script finds files in a specified   "
echo -e "directory and its subdirectories, and    "
echo -e "converts their extensions to lowercase.  "
echo -e "-----------------------------------------"
echo -e "${reset}"

# Ask the user if they want to use the current directory
read -p "Do you want to use the current directory to check for duplicate files? ([Y]es, [N]o, [Q]uit): " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice" in
    y) directory=$(pwd) ;;
    n) read -p "Enter the directory path to search for duplicate files: " directory ;;
    q) echo -e "Exiting script. Goodbye!"
       exit 0 ;;
    *) echo -e "${red}Invalid choice! EXITING SCRIPT!${reset}"
       exit 1 ;;
esac

# Validate the provided directory path
if [[ ! -d "$directory" ]]; then
    echo -e "${red}ERROR!${reset} The specified directory does not exist! Exiting script!"
    exit 1
fi

# Check if the directory is empty
if [ -z "$(find "$directory" -type f)" ]; then
    echo -e "${red}ERROR!${reset} The specified directory is empty! Exiting script!"
    exit 1
fi

# Process files in the specified directory and its subdirectories
find "$directory" -type f -name '*.*' -exec bash -c '
    base=${0%.*}
    ext=${0##*.}
    a=$base.${ext,,}
    [ "$a" != "$0" ] && mv -- "$0" "$a"
' {} \;

echo "File extensions have been converted to lowercase in the specified directory and its subdirectories."
