#!/bin/bash

## Verision 0.5
## License: Open Source GPL
## Copyright: (c) 2023

# Global variables for ANSI color
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Directories

# Create download directory
homedir="$HOME"
downdir="$homedir/Dropbox Downloads/"
mkdir -p "$downdir"
cd "$downdir" || return

# Start of script

read -rp "Paste Dropbox Link: " URL

# Validate URL
if [[ ! "$URL" =~ ^https:\/\/www\.dropbox\.com\/.*$ ]]; then
    echo "${red}Invalid URL!${reset} Please provide a valid Dropbox link."
    exit 1
fi

# if ! curl -s --head "$URL" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
#      echo "Dropbox link is not accessible or does not return a 200 status code. Please check the link and try again."
#      exit 1
# fi

echo "Creating download.zip file to not mangle files..."
sleep 1

curl --limit-rate 5M -L "$URL" -o download.zip

sleep 1

echo "Extracting files from download.zip"

7z x download.zip -aoa > /dev/null 2>&1

echo "Removing zip file..."
rm -f download.zip
echo "DONE!"
echo "Files saved to $downdir/"
