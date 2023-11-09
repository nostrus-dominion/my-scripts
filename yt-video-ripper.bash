#!/bin/bash

## Version 1.0
## License: Open Source GPL
## Copyright: (c) 2023
## Dependencies: yt-dlp, ffmpeg

#
## ALL THE BORING STUFF
#

# Global Variables for ANSI color
# Color variables
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
blue='\033[0;34m'
purple='\033[0;35m'
brown='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m' # No Color

#Checking if dependancies are installed
deps=("yt-dlp" "ffmpeg")

for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null; then
    echo -e "${red}CRITCAL ERROR!!!${reset} ${cyan}$dep${reset} is not installed or not in the PATH!"
    exit 1
fi
done

#
## Script initalizations
#

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${red}ERROR!!${reset} Do not run this script as root."
  exit 1
fi


#
## FUNCTIONS
#

# Function to ensure save directory exists and has read/write access
ensure_save_dir() {
  save_dir="$HOME/video-ripper"

  if [[ ! -d "$save_dir" ]]; then
    echo -e "${yellow}ALERT!${reset} This script is creating $save_dir."
    echo ""
    mkdir -p "$save_dir"
  elif [[ ! -w "$save_dir" ]]; then
    echo ""
    echo -e "${red}ERROR!!${reset} $save_dir is not read/writable! EXITING SCRIPT!"
    exit 1
  fi
}

# Function to validate media URLs
validate_media_url() {
  while true; do
    echo ""
    read -rp "Please enter the media URL (or 'exit' to quit): " media_url

    if [[ "$media_url" == "exit" ]]; then
      echo ""
      echo -e "${yellow}Exit chosen! Exiting script!${reset}"
      echo ""
      exit 0
    fi

    url_pattern="^https?://"

    if [[ $media_url =~ $url_pattern ]]; then
      # Use curl to send http request to validate URL and check response code
      http_status=$(curl -s -o /dev/null -w "%{http_code}" -L "$media_url")

    if [[ $http_status -ge 200 && $http_status -lt 300 ]]; then
      echo ""
      echo -e "URL is valid. HTTP Status Code: ${blue}$http_status${reset}"
      echo ""
      return 0
    else
      echo ""
      echo -e "${red}ERROR!${reset} Invalid URL. HTTP Status Code: $http_status"
      echo ""
      return 1
    fi

    else
      echo ""
      echo - e "${red}ERROR!${reset} Invalid URL. Please enter a valid URL."
      echo ""
      return 1

    fi

  done

}

# Function to download media files and save them in save_dir
download_media() {
  # Download media files and save them in save_dir
  yt-dlp --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" -o "$save_dir/%(title)s.%(ext)s" "$media_url"

  # Get the filename of the downloaded media file
  media_filename=$(yt-dlp --get-filename -o "%(title)s.%(ext)s" "$media_url")

  echo ""
  echo -e "${green}Download complete!${reset}"
  echo -e "Media file saved in: $save_dir"
  echo -e "Media file saved as: $media_filename"

}

# Display screen splash // FORMATING IS FUCKED DO NOT CHANGE
clear
echo -e "${brown}"
echo -e "			**********************************************			"
echo -e "			*                                            *			"
echo -e "			*           Welcome to the Internets         *			"
echo -e "			*                 Video Ripper               *			"
echo -e "			*                                            *			"
echo -e "			**********************************************			"
echo -e ""
echo -e "			This script rips videos from various media URLs			"
echo -e "		      by using yt-dlp with the highest possible bitrates.		"
echo -e "${reset}"

# Call ensure_save_dir function
ensure_save_dir

# Loop to do the actual work
while true; do
  # Call on validate_media_url function
  validate_media_url

  # Call on download_media function
  download_media
done
