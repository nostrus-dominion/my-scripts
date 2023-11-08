#!/bin/bash

## Version 1.5
## License: Open Source GPL
## Copyright: (c) 2023
## Dependencies: yt-dlp, ffmpeg

## ALL THE BORING STUFF

# Global Variables for ANSI color
brown='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

#Checking if dependancies are installed
deps=("yt-dlp" "ffmpeg")

for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null; then
    echo "${red}CRITCAL ERROR!!: $dep is not installed or not in the PATH${reset}"
    exit 1
fi
done

# Display screen splash
clear
echo -e "${brown}"
echo -e "			**********************************************			"
echo -e "			*                                            *			"
echo -e "			*           Welcome to the Youtube           *			"
echo -e "			*               Playlist Ripper              *			"
echo -e "	                *                      			     *			"
echo -e "			**********************************************			"
echo -e ""
echo -e "			This script rips videos from a YouTube playlist			"
echo -e "			using yt-dlp with the highest possible bitrates.		"
echo -e "${reset}"

# Function to validate playlist URL
validate_playlist_url() {
    read -rp "Enter the URL of the YouTube playlist: " playlist_url
    url_pattern="^(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/playlist"

    if [[ $playlist_url =~ $url_pattern ]]; then
        # Use curl to send a request to the URL and check the response status code
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "$playlist_url")

        if [[ $http_status -ge 200 && $http_status -lt 300 ]]; then
            return 0 # Valid URL
        else
            echo "Error: Invalid playlist URL. Please enter a valid YouTube playlist URL."
            return 1 # Invalid URL
        fi
    else
        echo "Error: Invalid playlist URL format. Please enter a valid YouTube playlist URL."
        return 1 # Invalid URL format
    fi
}


# Prompt the user for a valid playlist URL
while ! validate_playlist_url; do
    :
done

# Function to download videos from a playlist using yt-dlp
download_playlist() {
    playlist_url="$1"

    yt-dlp \
        --write-thumbnail \
        --embed-subs \
        --embed-thumbnail \
        --format "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4] / bv*+ba/b" \
        --merge-output-format mkv \
        --postprocessor-args "-map 0 -c copy -f nut -y" \
        --add-metadata \
        --convert-subs srt \
        --write-sub \
        --sub-lang en \
        --sub-format ass \
        --output "%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s" \ # Specify directory structure
        --download-archive downloaded.txt \
        "$playlist_url"
}

# Proceed with the download
echo "Proceeding with the download..."
download_playlist "$playlist_url"
