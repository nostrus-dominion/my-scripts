#!/bin/bash

## Verision 1.5
## License: Open Source GPL
## Copyright: (c) 2023

## ALL THE BORING STUFF

# Global Varibales for ANSI colors
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

# Script Splash
echo -e "${brown}"
echo -e "    Sequential Number Generator Script    "
echo -e "${reset}"

## BEGINNING OF SCRIPT
count=1
read -p "Enter a prefix for filenames: " user_prefix

echo "Preview of filename changes: "
for file in *; do
  if [[ -f "$file" ]]; then
    extension="${file##*.}"  # Extract the file extension
    printf -v padded_count "%03d" "$count"  # Pad the count with leading zeros
    new_name="${user_prefix}_${padded_count}.${extension}"
    echo "  $file -> $new_name"
    ((count++))
  fi
done

read -p "Do you want to proceed with these changes? (y/n) " choice
if [[ $choice =~ ^[Yy]$ ]]; then
  count=1  # Reset count for renaming
  for file in *; do
    if [[ -f "$file" ]]; then
      extension="${file##*.}"  # Extract the file extension
      printf -v padded_count "%03d" "$count"  # Pad the count with leading zeros
      new_name="${user_prefix}_${padded_count}.${extension}"
      mv "$file" "$new_name"
      ((count++))
    fi
  done
  echo "Files renamed successfully."
else
  echo "No changes were made. Exiting Script!"
  exit 1;
fi
