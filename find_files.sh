#!/bin/bash

## Version 1.2
## License: Open Source GPL
## Copyright: (c) 2023

## ALL THE BORING STUFF

# Global Color Variables
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

#
## BEGINNING OF SCRIPT
#

while true; do
    # Prompt the user for file name pattern
    echo -e -n "Enter file name pattern (or ${brown}'exit'${reset} to quit, or ${brown}'clear'${reset} to clean screen): "
    read pattern

    # Check user input
    if [ "$pattern" == "clear" ]; then
        clear
        echo "Cleared screen. Enter file name pattern (or 'exit' to quit): "
        continue
    fi

    if [ "$pattern" == "exit" ]; then
        echo "Exiting the script. Goodbye!"
        exit 0
    fi

    if [ -z "$pattern" ]; then
        echo -e "${red}ERROR!${reset} Input cannot be empty. Please try again."
        continue
    fi

    # Use find command to search for files matching the pattern in the current directory
    matching_files=$(find ./ -type f -iname "*$pattern*")

    if [ -z "$matching_files" ]; then
        # If no matching file found, prints an error message
        echo -e "${red}No matching file found! Try again!${reset}"
    else
        echo ""
        echo "Found the following files matching '$pattern':"
        echo "$matching_files" | sort

        # Count file types and display
        filetypes=$(echo "$matching_files" | grep -i -E -o "\.\w*$" | sort | uniq -c | awk '{printf "%-17s %s\n", $2, $1}')
        total_files=$(echo "$matching_files" | wc -l)

        # Display file types in columns
        echo -e "\nFiletype\tCount\n$filetypes"

        # Display total number of files found
        echo -e "\nTotal number of files found: $total_files"
    fi

    # Add a newline for better readability
    echo -e ""

    # Prompt user to save results to a text file
    read -p "Do you want to save the results to a text file? (yes/no): " save_to_file

    if [ "$save_to_file" == "yes" ]; then
        # Prompt user for the filename
        read -p "Enter the filename (without extension): " filename

        # Add suffix if file already exists
        counter=1
        while [ -e "$HOME/$filename.txt" ]; do
            filename="$filename-$counter"
            ((counter++))
        done

        # Save results to the text file
        echo -e "\nMatching files:\n$matching_files" > "$HOME/$filename.txt"
        echo -e "Filetype\tCount\n$filetypes" > "$HOME/$filename.txt"
        echo -e "\nTotal number of files found: $total_files" >> "$HOME/$filename.txt"

        echo "Results saved to: $HOME/$filename.txt"
    fi

done
