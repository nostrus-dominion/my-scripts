#!/bin/bash

# Version History
# Version 0.1 - edit date/time of files and directory recursively
# Version 0.2 - added directory validation, date/time validation
# Version 0.3 - added percentage counter, added any items that failed to change
# Version 0.4 - added colors, modified script usage

# Colors
red=$(tput setaf 1)
orange=$(tput setaf 166)
reset=$(tput sgr0) # No Color

# Script usage
if [ -z "$1" ]; then
  directory=$(pwd)
else
  directory="$1"
fi
if [ ! -d "$directory" ]; then
  echo -e ${red}"Directory $directory does not exist."
  echo -e "Exiting script!"${reset}
  exit 1
fi

# ASCII art splash screen

echo ""${orange}
echo "  _____        _          _____ _                                 "
echo " |  __ \      | |        / ____| |                                "
echo " | |  | | __ _| |_ ___  | |    | |__   __ _ _ __   __ _  ___ _ __ "
echo " | |  | |/ _| | __/ _ \ | |    | '_ \ / _| | '_ \ / _| |/ _ \ '__|"
echo " | |__| | (_| | ||  __/ | |____| | | | (_| | | | | (_| |  __/ |   "
echo " |_____/ \__,_|\__\___|  \_____|_| |_|\__,_|_| |_|\__, |\___|_|   "
echo "                                                   __/ |          "
echo "                                                  |___/           "
echo ""${reset}
echo "    A script to update creation dates of files and directories.   "

# Verify the current directory
echo
echo "Current directory: $(pwd)"
echo
read -rp "Do you wish to continue? (y/N): " dir_confirm

if [ "${dir_confirm,,}" != "yes" ] && [ "${dir_confirm,,}" != "y" ]; then
  echo
  echo "Exiting script!"
  exit 1
fi

cd "$directory" || exit 1

# Sanitize input for the target date and time
echo
read -rp "Enter the desired date and time (YYYY-MM-DD HH:MM:SS): " target_datetime

# Validate the date and time format
if ! date -d "$target_datetime" >/dev/null; then
  echo
  echo -e "${red}ERROR!${reset} Invalid date and time format. Please use the format YYYY-MM-DD HH:MM:SS."
  exit 1
fi


# Count total items
total_items=$(find . -type f -o -type d | wc -l)

# Initialize progress bar
echo -n "Changing creation date of items... "
echo ""
printf "["
for ((i=0; i<50; i++)); do printf " "; done
printf "]"

# Set up variables
error_occurred=false

# Iterate over items and change their creation date
find . -type f -o -type d | while IFS= read -r item; do
  current_item=$((current_item + 1))
  touch -d "$target_datetime" "$item" >/dev/null 2>&1

  # Update progress bar
  progress=$((current_item * 50 / total_items))
  printf "\rChanging creation date of items... ["
  for ((j=0; j<progress; j++)); do printf "#"; done
  for ((k=progress; k<50; k++)); do printf " "; done
  printf "] $((current_item * 100 / total_items))%% complete"

  # Check if an error occurred
  if [ $? -ne 0 ]; then
    error_occurred=true
    break
  fi
done

# Check if any error occurred and exit if true
if [ "$error_occurred" = true ]; then
  echo
  echo "Failed to change date for some items. Exiting script."
  exit 1
fi

echo ""
echo "Process completed. Updated the dates for $total_items items."
