#!/bin/bash

## Version 1.0
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
    read -p "Enter file name pattern (or ${brown}'exit'${reset} to quit, or ${brown}'clear'${reset} to clean screen): " pattern

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
        #If no matching file found prints error message
        echo -e "${red}No matching file found! Try again!${reset}"
    else
        echo ""
        echo "Found the following files matching '$pattern':"
        echo "$matching_files" | sort

    fi

    # Add a newline for better readability
    echo ""

done
