#!/bin/bash

## Verision 0.5
## License: Open Source GPL
## Copyright: (c) 2024

# Define colors
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
dim=$(tput dim)
reset=$(tput sgr0) # No Color

# Checking if dependancies are installed
deps=("ffmpeg")
for dep in "${deps[@]}"; do
	if ! which "$dep" > /dev/null; then
		echo ""
		echo -e "${red}CRITCAL ERROR!! $dep is not installed or not in the PATH${reset}"
		echo ""
		exit 1
	fi
done

# Check if the input filename is provided as a command-line argument
if [[ -z "$1" ]]; then
	echo ""
	echo "Usage: $0 input_file.mp4"
	echo ""
	exit 1
fi

input_file="$1"

# Check if the input file exists
if [[ ! -f "$input_file" ]]; then
	echo ""
	echo -e "${red}ERROR!${reset} File not found!"
	echo ""
	exit 1
fi

echo -e "${orange}"
echo -e "    ▗▄▄▖▗▄▄▖ ▗▄▄▄▖ ▗▄▖▗▄▄▄▖▗▄▖  ▗▄▄▖▗▄▄▄▖▗▄▄▄▖   "
echo -e "   ▐▌   ▐▌ ▐▌▐▌   ▐▌ ▐▌ █ ▐▌ ▐▌▐▌     █  ▐▌      "
echo -e "   ▐▌   ▐▛▀▚▖▐▛▀▀▘▐▛▀▜▌ █ ▐▛▀▜▌▐▌▝▜▌  █  ▐▛▀▀▘   "
echo -e "   ▝▚▄▄▖▐▌ ▐▌▐▙▄▄▖▐▌ ▐▌ █ ▐▌ ▐▌▝▚▄▞▘▗▄█▄▖▐▌      "
echo -e ""
echo -e "      Take a video file and make it a gif!       "
echo -e "${reset}"

# Prompt the user for the start time (seek position)
read -p "Enter the start time in seconds: " start_time
echo ""

# Prompt the user for the duration
read -p "Enter the duration in seconds: " duration
echo ""

# Prompt the user for the output filename
read -p "Enter the output filename: " output_file
echo ""

# Run the ffmpeg command
ffmpeg -ss "$start_time" -t "$duration" -i "$input_file" \
	-vf "fps=24,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
	-loop 0 "$output_file.gif"

if [[ $? -eq 0 ]]; then
	echo ""
	echo -e "${blue}GIF was created successfully!${reset} ${output_file}.gif"
	echo ""
else
	echo ""
	echo -e "${red}ERROR!{$reset} Failed to create gif."
	echo ""
fi
