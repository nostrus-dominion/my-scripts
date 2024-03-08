#!/bin/bash

# ASCII art splash screen

echo ""
echo "  _____        _          _____ _                                 "
echo " |  __ \      | |        / ____| |                                "
echo " | |  | | __ _| |_ ___  | |    | |__   __ _ _ __   __ _  ___ _ __ "
echo " | |  | |/ _| | __/ _ \ | |    | '_ \ / _| | '_ \ / _| |/ _ \ '__|"
echo " | |__| | (_| | ||  __/ | |____| | | | (_| | | | | (_| |  __/ |   "
echo " |_____/ \__,_|\__\___|  \_____|_| |_|\__,_|_| |_|\__, |\___|_|   "
echo "                                                   __/ |          "
echo "                                                  |___/           "

echo -e "\nWelcome to Date Changer - a script to update creation dates of files and directories."

# Verify the current directory
echo "Current directory: $(pwd)"
read -p "Is this the correct directory? (yes/no): " verify_directory

if [ "$verify_directory" != "yes" ]; then
    echo "Exiting script. Please navigate to the correct directory and run the script again."
    exit 1
fi

# Sanitize input for the target date and time
read -p "Enter the desired date and time (YYYY-MM-DD HH:MM:SS): " target_datetime

# Validate the date and time format
if ! [[ $target_datetime =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    echo "Invalid date and time format. Please use the format YYYY-MM-DD HH:MM:SS."
    exit 1
fi

total_items=$(find . -type f -o -type d | wc -l)
current_item=0

find . -type f -o -type d | while IFS= read -r item
do
  current_item=$((current_item + 1))
  percentage_complete=$((100 * current_item / total_items))
  echo -ne "\rChanging creation date of items... $percentage_complete% complete"

  if touch -d "$target_datetime" "$item"; then
    echo -ne "\nSuccessfully changed date for: $item"
  else
    echo -ne "\nFailed to change date for: $item"
  fi
done

echo -e "\nProcess completed. Updated the dates for $total_items items."

