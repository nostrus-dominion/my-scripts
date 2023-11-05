#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023

# Color variables
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
blue='\033[0;34m'
purple='\033[0;35m'
brown='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m' # No Color

# Checking if dependencies are installed
dependencies=("wget")
for cmd in "${dependencies[@]}"
do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo -e "${red}  ERROR:${reset} The command ${red} '$cmd' ${reset}is not installed, quitting :(" >&2
    exit 1
  fi
done

# Function to initialize script variables
initialize() {
    [[ -d $HOME/.pillager ]] || mkdir "$HOME/.pillager"
    SAVEPATH="$PWD"
    LIST=$HOME/.pillager/list
    INDEX="--reject index.html,index.html*"
    FLAGS="-r -np -nc "
    LOG="/tmp/website-size-log"
}

# Function to display help message
show_help() {
    echo "HELP"
    echo "By default, pillager will download all files"
    echo "recursively from a given link, avoiding index.html files,"
    echo "to the current working directory. A list of pillaged"
    echo "links is saved to ~/.pillager/list."
    echo "If no link is provided when called, you'll be prompted for a link."
    echo "OPTIONS"
    echo "-d [PATH]: Change download directory"
    echo "-h:        Show this message"
    echo "-i:        Include index.html files"
    echo "-l [LINK]: Link to pillage"
    echo "-m:        Mirror site"
    echo "-s:        Estimate link size"
    exit 1
}

# Function to parse command-line options
parse_options() {
    while getopts 'ishmd:l:' flag; do
        case "${flag}" in
            i) INDEX=" " ;;
            h) show_help ;;
            d) SAVEPATH="${OPTARG}" ;;
            m) FLAGS="-mkEpnp "
               INDEX=" " ;;
            l) LFLAG=1
               LINK="${OPTARG}" ;;
            s) SFLAG=1 ;;
            *) show_help ;;
        esac
    done
}

# Function to prompt user for link if not provided
get_link() {
    if [ -z "$LINK" ]; then
        echo -n "Link to pillage: "
        read -r LINK
    fi
}

# Function to estimate website size
estimate_size() {
    echo "Crawling site..."
    wget -rSnd -np -l inf --spider -o "$LOG" "${LINK}"
    echo "Finished crawling."
    sleep 1s
    echo "Estimated size: $(grep -e "Content-Length" "$LOG" | \
        awk '{sum+=$2} END {printf("%.0f", sum / 1024 / 1024)}'\
    ) Mb"
    rm "$LOG"
}

# Function to download files
download_files() {
    echo "$LINK" >> "$LIST"
    wget $FLAGS -e robots=off -c $INDEX "${LINK}" -P "$SAVEPATH"
}

# Main function
main() {
    initialize     # Initialize script variables
    parse_options "$@"  # Parse command-line options
    get_link           # Prompt user for link if not provided

    # Perform actions based on options
    if [ -v "$SFLAG" ]; then
        estimate_size   # Estimate website size
    else
        download_files  # Download files
    fi

    echo "Finished. Yar."
}

# Call the main function with command-line arguments
main "$@"
