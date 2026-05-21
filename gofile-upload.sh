#!/bin/bash

## Version 1.0
## License: Open Source GPL
## Copyright: (c) 2026

## GOFILE UPLOADER
## Uploads a file to GoFile.io and returns a shareable download link.

## ALL THE BORING STUFF

# Global Variables for ANSI color
red=$(tput setaf 1)
green=$(tput setaf 2)
orange=$(tput setaf 166)
reset=$(tput sgr0)

# Checking if dependencies are installed
deps=("curl" "jq")
for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null 2>&1; then
    echo -e "${red}CRITICAL ERROR!!${reset} $dep is not installed or not in the PATH!"
    exit 1
fi
done

## FUNCTIONS

# Function to validate file existence
validate_file() {
    local file=$1

    if [[ ! -f "$file" ]]; then
        echo ""
        echo -e "${red}ERROR!${reset} The specified file does not exist!"
        echo ""
        exit 1
    fi
}

# Function to get GoFile upload server
get_server() {
    echo ""
    echo -e "${orange}Contacting GoFile API and locating best upload server...${reset}"
    echo ""

    server=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

    if [[ -z "$server" || "$server" == "null" ]]; then
        echo -e "${red}CRITICAL ERROR!!${reset} Unable to retrieve upload server from GoFile API!"
        exit 1
    fi
}

# Function to upload file
upload_file() {
    local file=$1

    echo -e "${orange}Uploading file to GoFile...${reset}"
    echo ""

    upload_response=$(curl -# -F "file=@$file" "https://${server}.gofile.io/uploadFile" 2>/dev/null)

    download_link=$(echo "$upload_response" | jq -r '.data.downloadPage')

    if [[ -z "$download_link" || "$download_link" == "null" ]]; then
        echo ""
        echo -e "${red}UPLOAD FAILED!${reset} Could not retrieve download link!"
        echo ""
        exit 1
    fi
}

## BEGINNING OF SCRIPT

# Script splash
echo -e "${orange}"
echo " "
echo "   ██████╗  ██████╗ ███████╗██╗██╗     ███████╗    ██╗   ██╗██████╗ ██╗      ██████╗  █████╗ ██████╗ "
echo "  ██╔════╝ ██╔═══██╗██╔════╝██║██║     ██╔════╝    ██║   ██║██╔══██╗██║     ██╔═══██╗██╔══██╗██╔══██╗"
echo "  ██║  ███╗██║   ██║█████╗  ██║██║     █████╗      ██║   ██║██████╔╝██║     ██║   ██║███████║██║  ██║"
echo "  ██║   ██║██║   ██║██╔══╝  ██║██║     ██╔══╝      ██║   ██║██╔═══╝ ██║     ██║   ██║██╔══██║██║  ██║"
echo "  ╚██████╔╝╚██████╔╝██║     ██║███████╗███████╗    ╚██████╔╝██║     ███████╗╚██████╔╝██║  ██║██████╔╝"
echo "   ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝     ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ "
echo " "
echo -e "        Simple bash utility to upload files directly to GoFile.io and return a download link."
echo -e "${reset}"

## CHECKING ARGUMENTS

# Check if a file argument was provided
if [[ "$#" -eq 0 ]]; then
    echo ""
    echo -e "${red}ERROR!${reset} No file specified!"
    echo ""
    echo "Usage:"
    echo "   $0 /path/to/file"
    echo ""
    exit 1
fi

# Store file argument
FILE="$1"

# Validate file
validate_file "$FILE"

echo ""
echo -e "Selected file: ${green}$FILE${reset}"

## WHERE THE PARTY STARTS

# Retrieve upload server
get_server

echo -e "Using upload server: ${green}$server${reset}"

# Upload file
upload_file "$FILE"

# Display download link
echo ""
echo -e "${green}UPLOAD SUCCESSFUL!${reset}"
echo ""
echo -e "Download Link:"
echo -e "${orange}$download_link${reset}"
echo ""
echo "Enjoy your suspiciously convenient file hosting."
echo ""
