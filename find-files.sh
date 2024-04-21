#!/bin/bash

## Version 1.2
## License: Open Source GPL
## Copyright: (c) 2023

## ALL THE BORING STUFF

# Global Color Variables
red=$(tput setaf 1)
orange=$(tput setaf 166)
reset=$(tput sgr0) # No Color

#
## BEGINNING OF SCRIPT
#

while true; do
    # Prompt the user for file name pattern
    echo ""
    echo -e -n "Enter string pattern you wish to find: "
    read pattern

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
    read -p "Do you want to save the results to a text file? (y/N): " save_to_file

    # Check if input contains 'y', then proceed
    save_to_file=$(echo "$save_to_file" | tr '[:upper:]' '[:lower:]')
    if [[ "$save_to_file" == *"y"* ]]; then
        # Prompt user for the filename
        read -rp "Enter the filename (without extension): " filename

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

    # Prompt user if they wish to exit the script or clear the screen
    echo -e "Would you like to (${orange}'quit'${reset} to quit, or ${orange}'clear'${reset} to clean screen and look again?"
    read choice
    # Check user input
    if [ "$choice" == "clear" ]; then
        clear
        echo "Cleared screen."
        continue
    fi

    if [ "$choice" == "quit" ]; then
        echo "Exiting the script. Goodbye!"
        exit 0
    fi

    if [ -z "$choice" ]; then
        echo -e "${red}ERROR!${reset} Input cannot be empty. Please try again."
        continue
    fi
done
