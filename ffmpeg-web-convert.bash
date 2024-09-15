#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023
## Dependencies: FFmpeg, FFprobe

## CONSTANTS

# Color variables
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
orange=$(tput setaf 166)
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

# Define valid extensions
valid_extensions=(".mp4" ".mkv" ".avi" ".flv" ".wmv" ".mov" ".mpg" ".mpeg" ".m4v" ".webm" ".ogg" ".3gp" ".3g2" ".mj2")

# Function to check if an element is in an array
containsElement() {
  local element match="$1"
  shift
  for element; do
    [[ "$element" == "$match" ]] && return 0
  done
  return 1
}


# Function to validate if the provided path is a directory
validateDirectory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
	echo
        echo -e "${red}ERROR!${reset} The provided path is not a directory."
		echo
        return 1
    fi
}

# Function to validate filenames and make changes as needed
checkFilenames() {
    local invalid_files=0

    echo -e "Checking for unsupported filenames..."
	echo -e ""
	sleep 2

    for f in ./*; do
        if [[ "$f" == *"'"* ]]; then
            new_file=$(echo "$f" | tr -d "'")
            mv "$f" "$new_file"
            invalid_files=1
            echo "${yellow}WARNING!${reset} Invalid filename found: '$f' has been corrected."
        fi
    done

    if [[ $invalid_files -eq 0 ]]; then
        echo -e "All filenames are valid!"
		echo -e ""
    fi

	sleep 1

    echo -e "Checking for unsupported filenames DONE!"
}

# Function to confirm user wants to proceed after file count
confirmProceed() {
    read -p "Do you wish to proceed with converting the files listed above? ([Y]es, any other key for no): " proceed
    proceed=$(echo "$proceed" | tr '[:upper:]' '[:lower:]')
    if [[ "$proceed" != "yes" && "$proceed" != "y" ]]; then
        echo -e "${red}Aborted by user. Exiting script.${reset}"
        exit 0
    fi
}

### LETS GET THE PARTY STARTED!

# Script splash
echo -e "${orange}"
echo -e "  ______ ______ __  __ _____  ______ _____  __          ________ ____  "
echo -e " |  ____|  ____|  \/  |  __ \|  ____/ ____| \ \        / /  ____|  _ \ "
echo -e " | |__  | |__  | \  / | |__) | |__ | |  __   \ \  /\  / /| |__  | |_) |"
echo -e " |  __| |  __| | |\/| |  ___/|  __|| | |_ |   \ \/  \/ / |  __| |  _ < "
echo -e " | |    | |    | |  | | |    | |___| |__| |    \  /\  /  | |____| |_) |"
echo -e " |_|____|_|__  |_| _|_|_|   _|______\_____|_____\/ _\/___|______|____/ "
echo -e "  / ____/ __ \| \ | \ \    / /  ____|  __ \__   __|  ____|  __ \       "
echo -e " | |   | |  | |  \| |\ \  / /| |__  | |__) | | |  | |__  | |__) |      "
echo -e " | |   | |  | |     | \ \/ / |  __| |  _  /  | |  |  __| |  _  /       "
echo -e " | |___| |__| | |\  |  \  /  | |____| | \ \  | |  | |____| | \ \       "
echo -e "  \_____\____/|_| \_|   \/   |______|_|  \_\ |_|  |______|_|  \_\      "
echo -e " "
echo -e " This script is designed to convert video files into a web usable format"
echo -e " for ease of use on the majority of browsers. These files will be remuxed"
echo -e " into H264 / AAC format but will not change dimensions or framerates."
echo -e "${reset}"

# Ask the user if they are in the correct directory
current_directory=$(pwd)
while true; do
    echo -e "Your current directory is: " $current_directory  # Print the directory the user is
    echo -e ""
    read -p "Do you want to use the current directory to convert media files? ([Y]es, [N]o, [Q]uit): " choice
    echo -e ""
	choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        y) directory=$(pwd)
            break
            ;;  # Break the loop if the user chooses the current directory
        n) read -p "Enter the directory path to merge media files: " directory
            # Calls the validate_directory function and continue the loop if it's invalid
            if validateDirectory "$directory"; then
                break
            fi
            ;;
        q) echo "Exiting script. Goodbye!"
           exit 0
           ;;
        *) echo "Invalid choice! Please try again."
		   echo
		   ;;
    esac
done

# List files in directory
echo "Supported files available in the current directory:"
echo
for file in *.*; do
    extension=".${file##*.}"
    if containsElement "$extension" "${valid_extensions[@]}"; then
        echo "$file"
    fi
done
echo

# Calls on the confirmProceed function
confirmProceed

# Calls on checkFilenames function
checkFilenames

# Process each file in the directory
find "$directory" -type f | while IFS= read -r file; do
  filename=$(basename "$file")
  extension=".${filename##*.}"

  # Check if the file has a valid extension
  if containsElement "$extension" "${valid_extensions[@]}"; then
    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1 "$file")
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1 "$file")

    if [ "$video_codec" == "h264" ] && [ "$audio_codec" == "aac" ]; then
      echo -e "${yellow}Skipping $file as it already has the desired codecs.${reset}"
      sleep 2
      continue
    fi

    filename="${filename%.*}"

    if [ "$video_codec" != "h264" ]; then
      if [ "$audio_codec" == "aac" ]; then
        if ffmpeg -i "$file" -c:v h264 -c:a copy -y "$directory/$filename-websafe$extension" </dev/null; then
          echo -e "${green}SUCCESS!${reset} Conversion successful for $filename"
        else
          echo -e "${red}ERROR!${reset} CONVERSION FAILED! $filename was not successful."
        fi
      else
        if ffmpeg -i "$file" -c:v h264 -c:a aac -y "$directory/$filename-websafe$extension" </dev/null; then
          echo -e "${green}SUCCESS!${reset} Conversion successful for $filename"
        else
          echo -e "${red}ERROR!${reset} CONVERSION FAILED! $filename was not successful."
        fi
      fi
    else
      if [ "$audio_codec" != "aac" ]; then
        if ffmpeg -i "$file" -c:v copy -c:a aac -y "$directory/$filename-websafe$extension" </dev/null; then
          echo -e "${green}SUCCESS!${reset} Conversion successful for $filename"
        else
          echo -e "${red}ERROR!${reset} CONVERSION FAILED! $filename was not successful."
        fi
      fi
    fi
  fi
done

echo
echo "All conversions have been completed!"
echo
