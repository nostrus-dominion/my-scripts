#!/bin/bash

#FFMERGE
#Version 0.8.6
#License: Open Source (GPL)
#Copyright: (c) 2021
#Dependancy: ffmpeg, ffprobe

#Checking if dependancies are installed
deps=("ffmpeg" "ffprobe")

for dep in "${deps[@]}"; do
  if ! which "$dep" > /dev/null; then
    echo "Error: $dep is not installed or not in the PATH"
    exit 1
  fi
done

#User inputs
echo -e "WARNING! PLEASE BE SURE THAT ALL MEDIA IS OF THE SAME CODEC/CONTAINER!"
echo -e "THIS SCRIPT WILL NOT WORK IF YOUR MEDIA IS FROM DIFFERENT SOURCES!"

sleep 2s

echo -e "Please enter the file extension of your media:"
read -r file_extensions

echo -e "Please enter the name of the output:"
read -r new_output

# Check if all files are of the extension
files=$(find ./*."$file_extensions" 2>/dev/null | wc -l)
if [ "$files" -eq 0 ]; then
  echo "Error: No files found with extension $file_extensions"
  exit 1
fi

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
    echo "CRITICAL ERROR: ffmpeg encountered a problem attempting to run. Exit code: $ffmpeg_exit_code"
    echo "SCRIPT EXITING!!"
    exit 1
fi

# Read list.txt and delete input files listed in the file with user confirmation
if [[ -f "list.txt" ]]; then
    echo -e "The following files will be deleted:"
    cat list.txt
    read -p "Do you wish to delete these files? (y/n): " confirm_delete
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

rm list.txt
echo -e "Script complete! Exiting now! Goodbye!"
