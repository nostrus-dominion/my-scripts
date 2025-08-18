#!/bin/bash

# Check if an argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Check if the directory exists
if [ ! -d "$1" ]; then
    echo "Error: Directory '$1' not found."
    exit 1
fi

# Change to the specified directory
cd "$1" || exit

# Get the total number of files in the directory
total_files=$(find . -maxdepth 1 -type f | wc -l)

# Calculate the number of digits needed for padding
num_digits=$(echo -n "$total_files" | wc -c)

# Counter for numbering the files
count=1

# Get the first file to show an example
first_file=$(ls | grep -v '^\.' | head -n 1)

# Display the user prompt
echo "You are about to rename $total_files files."
echo "For example, ${first_file} will be renamed to ${first_file%.*}_$(printf "%0${num_digits}d" "$count").${first_file##*.}"
read -p "Do you wish to continue? (y/N) " choice

# Check the user's choice
case "$choice" in
    y|Y) echo "Renaming files..."
    ;;
    *) echo "Operation cancelled."
       exit
    ;;
esac

# Loop through each file in the directory
for file in *; do
    # Check if the file is a directory
    if [ -d "$file" ]; then
        # Skip directories
        continue
    fi

    # Get the name of the parent directory
    parent_dir=$(basename "$(pwd)")

    # Get the file extension
    extension="${file##*.}"

    # Pad the count with zeros
    padded_count=$(printf "%0${num_digits}d" "$count")

    # Rename the file to the name of the parent directory with numerical suffix and extension
    mv "$file" "${parent_dir}_${padded_count}.${extension}"

    ((count++))
done

echo "Files renamed successfully."
