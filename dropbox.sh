#!/bin/bash

# Version History
# Version 0.1 - created script and it was very bare bones
# Version 0.2 - added 7z extraction, forced overwrite and zip removal.
# Version 0.3 - added home directory download and URL verification

# CONSTANTS

# Directories

homedir="$HOME"

read -rp "Paste Dropbox Link: " URL

# Validate URL
if [[ ! "$URL" =~ ^https:\/\/www\.dropbox\.com\/.*$ ]]; then
    echo "Invalid Dropbox link. Please provide a valid Dropbox link."
    exit 1
fi
# if ! curl -s --head "$URL" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
#     echo "Dropbox link is not accessible or does not return a 200 status code. Please check the link and try again."
#     exit 1
# fi

# Download directory
downdir="$homedir/Dropbox Links"
mkdir -p "$downdir"
cd "$downdir" || return

echo "Creating download.zip file to not mangle files..."
sleep 1

curl --limit-rate 1M -L "$URL" -o download.zip

sleep 1

echo "Extracting files from download.zip"

7z x download.zip -aoa > /dev/null 2>&1

echo "Removing zip file..."
rm -f download.zip
echo "DONE!"
echo "Files saved to $downdir/"
