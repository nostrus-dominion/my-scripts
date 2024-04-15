#!/bin/bash

# Check if the rename command exists
if ! command -v rename &> /dev/null; then
    echo "Error: rename utility not found. Please install it."
    exit 1
fi

# Check if a directory is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

directory="$1"

# Check if the provided directory exists
if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' does not exist."
    exit 1
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

