#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023
## Dependencies: FFmpeg, FFprobe

# Color variables
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
reset=$(tput sgr0) # No Color

# Checking if dependencies are installed
dependencies=("ffmpeg" "ffprobe")
for cmd in "${dependencies[@]}"
do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo -e "${red}  ERROR:${reset} The command ${red} '$cmd' ${reset}is not installed, quitting :(" >&2
    exit 1
  fi
done

# Script splash
echo -e "${brown}"
echo -e "   ******************************    "
echo -e "   *                            *    "
echo -e "   *   File Converter for Web   *    "
echo -e "   *       by Using FFMPEG      *    "
echo -e "   *                            *    "
echo -e "   ******************************    "
echo -e ""
echo -e "   This script uses FFMpeg to convert  "
echo -e "   media files so that they can be     "
echo -e "   played on the web with no transcode."
echo -e "${reset}"

# Get the directory path from the user and validate it
read -r -p "Enter the directory path: " directory
if [ ! -d "$directory" ]
then
  echo -e "${red}Invalid directory path.${reset} Please enter a valid directory path and try again."
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
        echo -e "${yellow}Skipping $file as it already has the desired codecs.${reset}"
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

## Changing commit for git test
