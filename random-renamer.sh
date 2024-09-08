#!/bin/bash

## Version 1.0
## License: Open Source GPL
## Copyright: (c) 2023

yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Check if the rename command exists
if ! command -v rename &> /dev/null; then
    echo -e "${red}ERROR!${reset} The 'rename' linux utility is not found. Please install it."
    exit 1
fi

# Set the default directory to the current directory if not provided
directory="${1:-"$PWD"}"

# Check if the provided directory exists
if [ ! -d "$directory" ]; then
    echo -e "${red}ERROR!${reset} Directory '$directory' does not exist."
    echo -e "EXITING SCRIPT!"
    exit 1
fi

# Count the number of files in the directory
numOfFiles=$(find "$directory" -maxdepth 1 -type f | wc -l)

# Confirmation prompt
read -rp "Are you sure you want to rename $numOfFiles files in '$directory'? (y/N): " confirmation
if [[ ! $confirmation =~ ^[Yy]$ ]]; then
    echo -e "${yellow}Operation cancelled.${reset} Exiting script."
    exit 0
fi

# Change to the directory
cd "$directory" || exit

# Rename files randomly
for file in *; do
    if [ -f "$file" ]; then
        # Extract the file extension
        extension="${file##*.}"
        # Generate a random name
        new_name=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
        # Append the original file extension
        new_name="$new_name.$extension"
        # Check if the new name already exists (unlikely but you never know)
        while [ -e "$new_name" ]; do
            # Regenerate new name
            new_name=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
            new_name="$new_name.$extension"
        done
        # Rename the file
        mv "$file" "$new_name"
    fi
done

echo "Completed the task. Exiting script."
