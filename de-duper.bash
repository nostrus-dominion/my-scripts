#!/bin/bash

## Verision 2.1
## V1 Created 2021-02-07
## License: Open Source GPL
## Copyright: (c) 2023
## Dependancy: parallel

## ALL THE BORING STUFF

# Global Variables for ANSI color
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

#Checking if dependancies are installed
deps=("parallel" "find" "md5sum")

for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null; then
    echo -e "${red}CRITCAL ERROR!!: $dep is not installed or not in the PATH${reset}"
    exit 1
fi
done

## FUNCTIONS

# Function to validate if the provided path is a directory
validate_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        echo "Error: The provided path is not a directory."
        exit 1
    fi
}

# Function to confirm user wants to proceed after file count
confirm_proceed() {
    echo -e
    read -p "Do you want to proceed with finding duplicate files? ([Y]es, any other key for no): " proceed
    proceed=$(echo "$proceed" | tr '[:upper:]' '[:lower:]')
    if [[ "$proceed" != "yes" && "$proceed" != "y" ]]; then
        echo "Aborted by user. Exiting script."
        exit 0
    fi
}

# Function to get the number of threads for parallel processing
get_num_threads() {
    local available_threads=$(nproc)
    echo ""
    echo -e "Number of available threads on this system: ${red}$available_threads${reset}"
    read -p "Enter the number of threads for parallel processing (default is 1, maximum is $available_threads): " num_threads
    num_threads=${num_threads:-1}

    if [[ ! "$num_threads" =~ ^[1-9][0-9]*$ || "$num_threads" -gt "$available_threads" ]]; then
        echo -e "Invalid input. Using default value (1 thread). ${red}You go slow because you were being cute.${reset}"
        num_threads=1
    fi

    echo "Selected number of threads: $num_threads"
}

## BEGINNING OF SCRIPT

# Script splash
echo -e "${brown}"
echo -e "                                WELCOME TO THE SUPER-DE-DUPER SCRIPT                              "
echo -e "       ___  __  __  ____  ____  ____       ____   ____       ____   __  __  ____  ____  ____      "
echo -e "      / __)(  )(  )(  _ \( ___)(  _ \ ___ (  _ \ ( ___) ___ (  _ \ (  )(  )(  _ \( ___)(  _ \     "
echo -e "      \__ \ )(__)(  )___/ )__)  )   /(___) )(_) ) )__) (___) )(_) ) )(__)(  )___/ )__)  )   /     "
echo -e "      (___/(______)(__)  (____)(_)\_)     (____/ (____)     (____/ (______)(__)  (____)(_)\_)     "
echo -e "${reset}"


# Ask the user if they want to use the current directory
echo
read -p "Do you want to use the current directory to check for duplicate files? ([Y]es, [N]o, [Q]uit): " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice" in
    y) directory=$(pwd) ;;
    n) read -p "Enter the directory path to search for duplicate files: " directory ;;
    q) echo "Exiting script. Goodbye!"
       exit 0 ;;
    *) echo "Invalid choice! EXITING SCRIPT!"
       exit 1 ;;
esac

# Call the validate_directory fucntion to verify the provided directory
validate_directory "$directory"
echo
echo -e "Searching for duplicate files the following directory: "$directory

# Count the number of files in the directory
num_files=$(find "$directory" -type f | wc -l)
echo
echo -e "Number of files found in the directory and all subdirectories: ${red}$num_files${reset}"

if [[ "num_files" -gt 50000 ]]; then
    echo -e "${red}WARNING!${reset} This operation will take a long time to complete due to large file count."
fi

# Call the function for confirmation before proceeding
confirm_proceed

# Call the function to get the number of threads
get_num_threads

## WHERE THE PARTY STARTS

# Find and display duplicate files using MD5 hashes with parallel processing and progress indicator
# and using -print0 with find, -0 with parallel, and -0 for the md5sum checksum ensures proper handling
# of filenames with spaces or special characters.
duplicate_files=$(find "$directory" -type f -print0 | \
parallel --eta -j"$num_threads" -0 md5sum | \
sort | \
uniq -Dw32)

# Create duplicate-files.txt with timestamp for individual runs
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

if [[ -z "$duplicate_files" ]]; then
    echo ""
    echo "No duplicate files found!"
    echo "Exiting script! Goodbye!"
    echo ""
    exit 0
else
    # Save duplicate files to 'duplicate-files.txt' in the user's home directory
    echo ""
    echo "$duplicate_files" > "$HOME/duplicate-files-$timestamp.txt"
    echo "Duplicate files found. Results saved to $HOME/duplicate-files-$timestamp.txt"
    echo "Exiting script! Goodbye!"
    echo ""
    exit 0
fi
