#!/bin/bash

## Version 2.0
## License: Open Source GPL
## Copyright: (c) 2023

# Color variables
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Checking if dependencies are installed
dependencies=("wget")
for cmd in "${dependencies[@]}"
do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo -e "${red}ERROR!${reset} The binary ${red}'$cmd'${reset} is not installed. Quitting script. :(" >&2
    exit 1
  fi
done

# Function to initialize script variables
initialize() {
    [[ -d $HOME/.pillager ]] || mkdir "$HOME/.pillager"
    savepath="$HOME/Pillager/"
    list=$HOME/.pillager/list
    index="--reject index.html,index.html*"
    flags="-r -np -nc "
    log="/tmp/website-size-log"
}

# Function to display help message
show_help() {
    echo "Oh you need help?"
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
            i) index=" " ;;
            h) show_help ;;
            d) savepath="${OPTARG}" ;;
            m) flags="-mkEpnp "
               index=" " ;;
            l) lflag=1
               link="${OPTARG}" ;;
            s) sflag=1 ;;
            *) show_help ;;
        esac
    done
}

# Function to prompt user for link if not provided
get_link() {
    if [ -z "$link" ]; then
        echo -n "Link to pillage: "
        read -r link
    fi
}

# Function to estimate website size
estimate_size() {
    echo "Crawling site..."
    wget -rSnd -np -l inf --spider -o "$log" "${link}"
    echo "Finished crawling."
    sleep 1s
    echo "Estimated size: $(grep -e "Content-Length" "$log" | \
        awk '{sum+=$2} END {printf("%.0f", sum / 1024 / 1024)}'\
    ) Mb"
    rm "$log"
}

# Function to download files
download_files() {
    echo "$link" >> "$list"
    echo "Downloading files..."
    wget $flags -e robots=off -c $index "${link}" -P "$savepath" /dev/null 2>&1
}

# Main function
main() {
    initialize     # Initialize script variables
    parse_options "$@"  # Parse command-line options
    get_link           # Prompt user for link if not provided

    # Perform actions based on options
    if [ -v "$sflag" ]; then
        estimate_size   # Estimate website size
    else
        download_files  # Download files
    fi

    echo "Finished. Yar."
}

# Call the main function with command-line arguments
main "$@"
