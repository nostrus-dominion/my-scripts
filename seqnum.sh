#!/bin/bash

## Version 1.7
## License: Open Source GPL
## Copyright: (c) 2023

#######################
## ALL THE BORING STUFF
#######################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check.
dependencies=("tput" "mv")
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

##################
## START OF SCRIPT
##################

# Script Splash
echo -e "${orange}"
cat << 'SPLASH'
Sequential Number Generator Script
SPLASH
}
echo -e "${reset}"
read -rp "Enter a prefix (max 64 char): " user_prefix
echo -e ""

# Check prefix length
if [ ${#user_prefix} -gt 64 ]; then
  echo "${red}ERROR!${reset} Prefix cannot exceed 64 characters."
  exit 1
fi

# Create an array to store file names
files=()
for file in *; do
  if [[ -f "$file" ]]; then
    files+=("$file")
  fi
done

# Determine the padding length based on the number of files
file_count=${#files[@]}
padding_length=$((${#file_count} + 2)) # Add 2 for underscore and dot

# Display filename changes before renaming
count=1
for file in "${files[@]}"; do
  extension="${file##*.}"                                # Extract the file extension
  printf -v padded_count "%0${padding_length}d" "$count" # Pad the count with leading zeros
  new_name="${user_prefix}_${padded_count}.${extension}"
  echo "[$file] --> [$new_name]"
  ((count++))
done

# Ask for confirmation before renaming the files
echo -e ""
read -rp "Confirm renaming the files? (y/n): " confirm
echo -e ""
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  # Rename the files with padded numbers
  count=1
  for file in "${files[@]}"; do
    extension="${file##*.}"                                # Extract the file extension
    printf -v padded_count "%0${padding_length}d" "$count" # Pad the count with leading zeros
    new_name="${user_prefix}_${padded_count}.${extension}"
    mv "$file" "$new_name"
    ((count++))
  done
  echo "Files renamed successfully."
else
  echo "Files not renamed."
fi
