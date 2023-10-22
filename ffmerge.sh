#!/bin/bash

#FFMERGE
#Version 0.8
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
files=$(ls *.$file_extensions 2>/dev/null | wc -l)
if [ $files -eq 0 ]; then
  echo "Error: No files found with extension $file_extensions"
  exit 1
fi

# Countdown for user confirmation to cancel
echo -e "Five second countdown to [CTRL-C] to cancel"
for i in {5..1};do echo -n "$i." && sleep 1; done

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
for f in ./*.$file_extensions; do
    echo "file '$f'" >> list.txt
done
ffmpeg -f concat -safe 0 -i list.txt -c copy "$new_output.$file_extensions" &
pid=$!
wait $pid

# User confirmation for original file deletion
read -p "Do you wish to delete all original files? (y/n): " confirm
if [[ "${confirm,,}" == "y" ]]; then
    for f in ./*.$file_extensions; do
        if [[ "$f" != "$new_output.$file_extensions" ]]; then
            rm "$f" list.txt
        fi
    done
    echo "Original files were deleted."
else
    echo "Original files were not deleted."
fi

# Script exit
echo -e "Script complete! Exiting now! Goodbye!"
