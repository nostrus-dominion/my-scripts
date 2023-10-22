#!/bin/bash

#FFMERGE
#Version 1.1
#License: Open Source (GPL)
#Copyright: (c) 2023
#Dependancy: ffmpeg, ffprobe

# Global Variables for ANSI color
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

#Checking if dependancies are installed
deps=("ffmpeg" "ffprobe")

for dep in "${deps[@]}"; do
  if ! which "$dep" > /dev/null; then
    echo "${red}CRITCAL ERROR!!: $dep is not installed or not in the PATH${reset}"
    exit 1
  fi
done

# Script splash
echo -e "${brown}"
echo -e "                                          Welcome to FFMERGE SCRIPT                               "
echo -e '  ______ ______ __  __ ______ _____   _____ ______        _____  _____ _____  _____ _____ _______ '
echo -e ' |  ____|  ____|  \/  |  ____|  __ \ / ____|  ____|      / ____|/ ____|  __ \|_   _|  __ \__   __|'
echo -e ' | |__  | |__  | \  / | |__  | |__) | |  __| |__        | (___ | |    | |__) | | | | |__) | | |   '
echo -e ' |  __| |  __| | |\/| |  __| |  _  /| | |_ |  __|        \___ \| |    |  _  /  | | |  ___/  | |   '
echo -e ' | |    | |    | |  | | |____| | \ \| |__| | |____       ____) | |____| | \ \ _| |_| |      | |   '
echo -e ' |_|    |_|    |_|  |_|______|_|  \_\\_____|______|     |_____/ \_____|_|  \_\_____|_|      |_|   '
echo "${reset}"
echo "    This script assumes you are within the correct directory. If not please CTRL-C to exit.          "
echo ""

sleep 2s

# File extension input with validation
while true; do
    read -rp "Please enter the file extension of your media: " file_extensions
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

# New name input
while true; do
    read -rp "Please enter the new name of your media: " new_output
    if [[ -n "$new_output" ]]; then
        break
    else
        echo "ERROR: New name cannot be blank. Please try again."
    fi
done

# Countdown for user confirmation to cancel
echo -e "Five second countdown to [CTRL-C] to cancel"
for i in {5..1};do echo -n "$i." && sleep 1; done
echo ""

# Function to validate filenames and make changes as needed
function check_filenames {
    local invalid_files=0

    echo -e "Checking for unsupported filenames..."

    for f in ./*; do
        if [[ "$f" == *"'"* ]]; then
            new_file=$(echo "$f" | tr -d "'")
            mv "$f" "$new_file"
            invalid_files=1
            echo "Invalid filename found: '$f' has been corrected to '$new_file'"
        fi
    done

    if [[ $invalid_files -eq 0 ]]; then
        echo "All filenames are valid!"
    fi

    echo -e "Checking for unsupported filenames DONE!"
}

# Call check_filenames
check_filenames

# Function to display a progress bar
function show_progress {
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

# Function to validate codec and container of all files using ffprobe
function validate_files {
    echo "Validating file codecs and containers..."
    local total_files
    total_files=$(find . -maxdepth 1 -type f -name "*.$file_extensions" | wc -l)
    local current_file=0
    local file_info
    local file_codec
    local file_container

    for file in *."$file_extensions"; do
        # Get codec and container using ffprobe and store it in a variable
        file_info=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
        file_codec=$(head -n 1 <<< "$file_info")

        file_info=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$file")
        file_container=$(head -n 1 <<< "$file_info")

        # Initialize codec and container if not set
        if [[ -z "$codec" ]]; then
            codec="$file_codec"
        fi

        if [[ -z "$container" ]]; then
            container="$file_container"
        fi

        # Compare codec and container with previous files
        if [[ "$file_codec" != "$codec" || "$file_container" != "$container" ]]; then
            echo ""
            echo -e "${red}CRITICAL ERROR!! $file has a different codec or container!"
            echo -e "${red}EXITING SCRIPT!!${reset}"
            exit 1
        fi

        # Call on show_progress function and update progress bar
        ((current_file++))
        local progress=$((current_file * 100 / total_files))
        show_progress "$progress"
    done

    echo ""  # Move to the next line after the progress bar is completed
    echo "All files codecs and containers have been validated!!"
}

# ...

# Call the validate_files function
validate_files

# Creation of concat list and running ffmpeg to merge files
echo -e "Attempting to combine files..."
for f in ./*."$file_extensions"; do
    echo "file '$f'" >> list.txt
done
ffmpeg -f concat -safe 0 -i list.txt -c copy "$new_output.$file_extensions" &
pid=$!
wait $pid

ffmpeg_exit_code=$? # Exit code for ffmpeg
if [[ $ffmpeg_exit_code -ne 0 ]]; then
    rm list.txt
    echo "${red}CRITICAL ERROR!! FFMPEG has encountered a problem! Exit code: $ffmpeg_exit_code"
    echo "${red}EXITING SCRIPT !!${reset}"
    exit 1
fi

# Read list.txt and delete input files listed in the file with user confirmation
if [[ -f "list.txt" ]]; then
    echo -e ""
    echo -e "The following files will be deleted:"
        cat list.txt

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
        echo -e "No input received within 30 seconds. Assuming 'n' (no)."
        confirm_delete="n"
    fi
else
    echo -e "Error: list.txt not found. Original files were not deleted."
fi

# Delete list.txt
rm list.txt

# Script complete. Exiting.
echo -e "Script complete! Exiting now! Goodbye!"
