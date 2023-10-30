#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023
## Dependencies: FFmpeg, FFprobe

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Checking if dependencies are installed
dependencies=("ffmpeg" "ffprobe")
for cmd in "${dependencies[@]}"
do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo -e "${RED}  ERROR:${NC} The command ${RED} '$cmd' ${NC}is not installed, quitting :(" >&2
    exit 1
  fi
done

# Get the directory path from the user and validate it
read -r -p "Enter the directory path: " directory
if [ ! -d "$directory" ]
then
  echo -e "${RED}Invalid directory path.${NC} Please enter a valid directory path and try again."
  exit 1
fi

read -r -p "Are you sure you wish to continue? (y/n) " confirm

valid_extensions=(".mp4" ".mkv" ".avi" ".flv" ".wmv" ".mov" ".mpg" ".mpeg" ".m4v" ".webm" ".ogg" ".3gp" ".3g2" ".mj2")

if [ "$confirm" == "y" ]
then
  for file in $(find "$directory" -type f); do
    filename=$(basename "$file")
    extension="${filename##*.}"
    if [[  ${valid_extensions[*]}  =~  ${extension}  ]]; then
      video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1 "$file")
      audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1 "$file")
      if [ "$video_codec" == "h264" ] && [ "$audio_codec" == "aac" ]
      then
        echo -e "${YELLOW}Skipping $file as it already has the desired codecs.${NC}"
        sleep 2
        continue
      fi
      if [ "$video_codec" != "h264" ]
      then
        if [ "$audio_codec" == "aac" ]
        then
          filename="${filename%.*}"
          ffmpeg -i "$file" -c:v h264 -c:a copy -y "$directory/$filename-h264.$extension"
        else
          filename="${filename%.*}"
          ffmpeg -i "$file" -c:v h264 -c:a aac -y "$directory/$filename-h264-aac.$extension"
        fi
      else
        if [ "$audio_codec" != "aac" ]
        then
          filename="${filename%.*}"
          ffmpeg -i "$file" -c:v copy -c:a aac -y "$directory/$filename-aac.$extension"
        fi
      fi
    fi
 done
 echo "Conversions complete!"
 else
 echo "All done!"
fi
