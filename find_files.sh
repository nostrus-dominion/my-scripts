#!/bin/bash

while true; do
    # Prompt the user for file name pattern
    read -p "Enter file name pattern (or 'exit' to quit, or 'clear' to clean screen): " pattern

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
            echo "ERROR! Input cannot be empty. Please try again."
            continue
    fi

    # Use find command to search for files matching the pattern in the current directory
    matching_files=$(find ./ -type f -iname "*$pattern*")

    if [ -z "$matching_files" ]; then
        #If no matching file found prints error message
        echo -e "\e[31mNo matching file found! Try again!\e[0m"
    else
        echo
        echo "Found the following files matching '$pattern':"
        echo "$matching_files" | sort

    fi

    # Add a newline for better readability
    echo

done
