#!/bin/bash

#FFMERGE-FILES
#Version 2.0
#License: Open Source (GPL)
#Copyright: (c) 2023

# CONSTANTS

# Variables for ANSI color
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
reset=$(tput sgr0) # No Color

#Checking if dependancies are installed
deps=("ffmpeg" "ffprobe")

for dep in "${deps[@]}"; do
  if ! which "$dep" > /dev/null; then
    echo "${red}CRITCAL ERROR!!${reset} $dep is not installed or not in PATH."
    exit 1
  fi
done

## FUNCTIONS

# Function to validate if the provided path is a directory
validateDirectory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
	echo
        echo -e "${red}ERROR!${reset} The provided path is not a directory."
		echo
        return 1
    fi
}

# Function to validate filenames and make changes as needed
checkFilenames() {
    local invalid_files=0

    echo -e "Checking for unsupported filenames..."
	echo -e ""
	sleep 4

    for f in ./*; do
        if [[ "$f" == *"'"* ]]; then
            new_file=$(echo "$f" | tr -d "'")
            mv "$f" "$new_file"
            invalid_files=1
            echo "${yellow}WARNING!${reset} Invalid filename found: '$f' has been corrected."
        fi
    done

    if [[ $invalid_files -eq 0 ]]; then
        echo -e "All filenames are valid!"
		echo -e ""
    fi

	sleep 1

    echo -e "Checking for unsupported filenames DONE!"
}

# Function to confirm user wants to proceed after file count
confirmProceed() {
    echo -e
    read -p "Proceed with merging all .$file_extensions files into $new_output.$file_extensions file? ([Y]es, any other key for no): " proceed
    proceed=$(echo "$proceed" | tr '[:upper:]' '[:lower:]')
    if [[ "$proceed" != "yes" && "$proceed" != "y" ]]; then
        echo -e "${red}Aborted by user. Exiting script.${reset}"
        exit 0
    fi
}

# Function to display a progress bar
showProgress() {
    local percentage=$1
    local width=50
    local completed=$((percentage * width / 100))
    local remaining=$((width - completed))
    local progress_bar="["
    for ((i=0; i<completed; i++)); do
        progress_bar+="="
    done
    for ((i=0; i<remaining; i++)); do
        progress_bar+=" "
    done
    progress_bar+="] ($percentage%)"
    echo -ne "\r$progress_bar"
}

# Function to validate codec of all files using ffprobe
validateFiles() {
    echo -e ""
	echo "Validating file codecs..."
	local total_files
    total_files=$(find . -maxdepth 1 -type f -name "*.$file_extensions" | wc -l)
    local current_file=0
    local file_info
    local file_codec

    for file in *."$file_extensions"; do
        # Get codec using ffprobe and store it in a variable
        file_info=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
        file_codec=$(head -n 1 <<< "$file_info")

        # Initialize codec if not set
        if [[ -z "$codec" ]]; then
            codec="$file_codec"
        fi

        # Compare codec with previous files
        if [[ "$file_codec" != "$codec" ]]; then
            echo -e ""
            echo -e "${red}CRITICAL ERROR!! $file has a different codec!"
            echo -e "${red}EXITING SCRIPT!!${reset}"
            echo -e ""
            exit 1
        fi

        # Call on show_progress function and update progress bar
        ((current_file++))
        local progress=$((current_file * 100 / total_files))
        showProgress "$progress"
    done

    echo -e ""  # Move to the next line after the progress bar is completed
	echo -e ""  # Adds a space between progress bar
    echo -e "All files codecs have been validated!!"
	sleep 1
}

## SCRIPT BEGINNING

# Script splash
echo -e "${orange}"
echo -e "                                   Welcome to FFMERGE SCRIPT                                       "
echo -e "                   This script will merge multiple media files into one file.                      "
echo -e ""
echo -e '  ______ ______ __  __ ______ _____   _____ ______        _____  _____ _____  _____ _____ _______  '
echo -e ' |  ____|  ____|  \/  |  ____|  __ \ / ____|  ____|      / ____|/ ____|  __ \|_   _|  __ \__   __| '
echo -e ' | |__  | |__  | \  / | |__  | |__) | |  __| |__        | (___ | |    | |__) | | | | |__) | | |    '
echo -e ' |  __| |  __| | |\/| |  __| |  _  /| | |_ |  __|        \___ \| |    |  _  /  | | |  ___/  | |    '
echo -e ' | |    | |    | |  | | |____| | \ \| |__| | |____       ____) | |____| | \ \ _| |_| |      | |    '
echo -e ' |_|    |_|    |_|  |_|______|_|  \_\\\_____|______|     |_____/ \_____|_|  \_\_____|_|      |_|   '
echo -e ""
echo -e "                    This script assumes you are within the correct directory.                      "
echo -e "                    If not please enter the directory you want or use 'Q' to quit.                 "
echo -e "${reset} "

# Ask the user if they are in the correct directory
current_directory=$(pwd)
while true; do
    echo -e "Your current directory is: " $current_directory  # Print the directory the user is
    echo -e ""
    read -p "Do you want to use the current directory to merge media files? ([Y]es, [N]o, [Q]uit): " choice
    echo -e ""
	choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        y) directory=$(pwd)
            break
            ;;  # Break the loop if the user chooses the current directory
        n) read -p "Enter the directory path to merge media files: " directory
            # Calls the validate_directory function and continue the loop if it's invalid
            if validateDirectory "$directory"; then
                break
            fi
            ;;
        q) echo "Exiting script. Goodbye!"
           exit 0
           ;;
        *) echo "Invalid choice! Please try again." 
		   echo
		   ;;
    esac
done

# List files in directory
echo "Files available in the current directory:"
echo 
for file in *.*; do
	echo "$file"
done
echo

# Find file extension and validate
while true; do
    read -rp "Please enter the extension of the media you want to combine: " file_extensions
    if [[ -n "$file_extensions" ]]; then
        if ls ./*."$file_extensions" 1> /dev/null 2>&1; then
            break
        else
            echo "ERROR: No files found with that extension. Please try again."
        fi
    else
        echo "ERROR: File extension cannot be blank. Please try again."
    fi
done

# New output name
while true; do
    read -rp "Please enter the new name of your media: " new_output
    if [[ -n "$new_output" ]]; then
        # Check if the new_output already exists in the current directory
        if [[ -e "$new_output.$file_extensions" ]]; then
            echo "ERROR: '$new_output.$file_extensions' already exists in this directory. Please choose a different name."
        else
            break
        fi
    else
        echo "ERROR: New name cannot be blank. Please try again."
    fi
done

# Call the check filesnames Function
echo
checkFilenames

# Call confirm_proceed Function
confirmProceed

# Call the validate_files function
validateFiles

# Creation of concat list and running ffmpeg to merge files
echo -e "Attempting to combine files..."
sleep 2
for f in ./*."$file_extensions"; do
    echo "file '$f'" >> list.txt
done
ffmpeg -f concat -safe 0 -i list.txt -c copy "$new_output.$file_extensions" &
pid=$!
wait $pid

ffmpeg_exit_code=$? # Exit code for ffmpeg
if [[ $ffmpeg_exit_code -ne 0 ]]; then
    rm list.txt
    echo -e "${red}CRITICAL ERROR!! FFMPEG has encountered a problem! Exit code: $ffmpeg_exit_code"
    echo -e "${red}EXITING SCRIPT !!${reset}"
    exit 1
fi

# Read list.txt and delete input files listed in the file with user confirmation
if [[ -f "list.txt" ]]; then
    echo -e ""
    echo -e "The following files will be deleted:"
	echo
	# Reads files with the specified file extension from list.txt
    grep "\\.$file_extensions'$" list.txt
	echo
    
    # Set a 30-second timeout for user input
    if read -t 30 -rp "Do you wish to delete these files? (y/n): " confirm_delete; then
        # User provided input within the 30-second timeout
        if [[ "${confirm_delete,,}" == "y" ]]; then
            echo -e "Deleting original files..."
            while IFS= read -r line; do
                file_to_delete=$(echo "$line" | awk -F "'" '{print $2}' | tr -d "'")
                if [[ -f "$file_to_delete" ]]; then
                    rm "$file_to_delete"
                else
                    echo "File not found: $file_to_delete"
                fi
            done < list.txt
            echo -e "Original files deleted!"
        else
            echo -e "Files will not be deleted. Exiting."
        fi
    else
        # User did not provide input within the 30-second timeout
        echo ""
        echo -e "No input received within 30 seconds. Assuming 'no'."
        confirm_delete="n"
    fi
else
    echo -e "Error: list.txt not found. Original files were not deleted."
fi

# Delete list.txt
rm list.txt

# Script complete. Exiting.
echo -e "Script complete! Exiting now! Goodbye!"
