#!/bin/bash

#FFMERGE
#Version 1.0
#License: Open Source (GPL)
#Copyright: (c) 2023
#Dependancy: ffmpeg, ffprobe

#Checking if dependancies are installed
deps=("ffmpeg" "ffprobe")

for dep in "${deps[@]}"; do
  if ! which "$dep" > /dev/null; then
    echo "Error: $dep is not installed or not in the PATH"
    exit 1
  fi
done

# Script splash
echo "********************************************"
echo "*              FFMERGE SCRIPT              *"
echo "*          To Simplify Your Life           *"
echo "********************************************"
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

#Removes unsupported filenames
echo -e "Checking and removing unsupported filename types..."
for f in ./*; do
    if [[ "$f" == *"'"* ]]; then
        new_file=$(echo "$f" | tr -d "'")
        mv "$f" "$new_file"
    fi
done
echo -e "Removing unsupported filename types DONE!"
sleep 1s

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
    echo "Validating all files..."
    local total_files=$(find . -maxdepth 1 -type f -name "*.$file_extensions" | wc -l)
    local current_file=0

    for file in *."$file_extensions"; do
        # Get codec and container using ffprobe
        info=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
        file_codec=$(echo "$info" | head -n 1)

        info=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$file")
        file_container=$(echo "$info" | head -n 1)

        # Initialize codec and container if not set
        if [[ -z "$codec" ]]; then
            codec="$file_codec"
        fi

        if [[ -z "$container" ]]; then
            container="$file_container"
        fi

        # Compare codec and container with previous files
        if [[ "$file_codec" != "$codec" || "$file_container" != "$container" ]]; then
            echo "Error: $file has a different codec or container"
            exit 1
        fi

        # Update progress bar
        ((current_file++))
        local progress=$((current_file * 100 / total_files))
        show_progress "$progress"
    done

    echo ""  # Move to the next line after the progress bar is completed
    echo "All files have been validated!!"
}

# Call the validate_files function before proceeding
validate_files

# Creation of concat list and running ffmpeg to merge files
echo -e "Combining all files into one..."
for f in ./*."$file_extensions"; do
    echo "file '$f'" >> list.txt
done
ffmpeg -f concat -safe 0 -i list.txt -c copy "$new_output.$file_extensions" &
pid=$!
wait $pid

ffmpeg_exit_code=$? # Exit code for ffmpeg
if [[ $ffmpeg_exit_code -ne 0 ]]; then
    rm list.txt
    echo "CRITICAL ERROR: ffmpeg encountered a problem attempting to run. Exit code: $ffmpeg_exit_code"
    echo "SCRIPT EXITING!!"
    exit 1
fi

# Read list.txt and delete input files listed in the file with user confirmation
if [[ -f "list.txt" ]]; then
    echo -e "The following files will be deleted:"
    cat list.txt
    read -rp "Do you wish to delete these files? (y/n): " confirm_delete
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
    echo -e "Error: list.txt not found. Original files were not deleted."
fi

# Delete list.txt
rm list.txt

# Script complete. Exiting.
echo -e "Script complete! Exiting now! Goodbye!"
