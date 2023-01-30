#!/bin/bash

echo -e "Enter media URL:" 
read -r media_url

if ! curl --output /dev/null --silent --head --fail "$media_url"; then
  echo "Error: Invalid media URL."
  echo "Exiting Script!"
  exit 1
else
  yt-dlp --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$media_url"
  echo "Download complete."
fi

