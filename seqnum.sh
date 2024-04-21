#!/bin/bash

## Verision 1.6
## License: Open Source GPL
## Copyright: (c) 2023

## ALL THE BORING STUFF

# Global Varibales for ANSI colors
orange=$(tput setaf 166)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Script Splash
echo -e "${orange}"
echo -e "Sequential Number Generator Script"
echo -e ""${reset}


## BEGINNING OF SCRIPT

read -p "Enter a prefix: " user_prefix
echo -e ""

# Create an array to store file names
files=()

# Populate the array with file names
for file in *; do
  if [[ -f "$file" ]]; then
    files+=("$file")
  fi
done

# Sort the array to maintain the original order
sorted_files=($(printf "%s\n" "${files[@]}" | sort))

# Display filename changes before renaming
count=1
for file in "${sorted_files[@]}"; do
  extension="${file##*.}"  # Extract the file extension
  printf -v padded_count "%03d" "$count"  # Pad the count with leading zeros to make it 3 digits long
  new_name="${user_prefix}_${padded_count}.${extension}"
  echo "[$file] --> [$new_name]"
  ((count++))
done

# Ask for confirmation before renaming the files
echo -e ""
read -p "Confirm renaming the files? (y/n): " confirm
echo -e ""
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  # Rename the files with padded numbers
  count=1
  for file in "${sorted_files[@]}"; do
    extension="${file##*.}"  # Extract the file extension
    printf -v padded_count "%03d" "$count"  # Pad the count with leading zeros to make it 3 digits long
    new_name="${user_prefix}_${padded_count}.${extension}"
    mv "$file" "$new_name"
    ((count++))
  done
  echo "Files renamed successfully."
else
  echo "Files not renamed."
fi
