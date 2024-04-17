#!/bin/bash

# Check if the rename command exists
if ! command -v rename &> /dev/null; then
    echo "Error: rename utility not found. Please install it."
    exit 1
fi

# Set the default directory to the current directory if not provided
directory="${1:-"$PWD"}"

# Check if the provided directory exists
if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' does not exist."
    exit 1
fi

# Count the number of files in the directory
numOfFiles=$(find "$directory" -maxdepth 1 -type f | wc -l)

# Confirmation prompt
read -p "Are you sure you want to rename $numOfFiles files in '$directory'? (y/N): " confirmation
if [[ ! $confirmation =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
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
        # Rename the file
        mv "$file" "$new_name"
        echo "Renamed '$file' to '$new_name'"
    fi
done
