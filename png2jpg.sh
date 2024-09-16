#!/bin/sh

## Version 1.1
## License: Open Source GPL
## Copyright: (c) 2023
## Not my original work but I changed things to make it more readable

###########################################
## THE ORIGINAL AUTHOR
##
## https://github.com/mitchweaver/bin
##
############################################

# Color variables
yellow=$(tput setaf 3)
red=$(tput setaf 1)
orange=$(tput setaf 166)
reset=$(tput sgr0) # No Color

# Checking if dependencies are installed
deps=("convert" "jpegoptim")
for dep in "${deps[@]}"; do
    if ! which "$dep" > /dev/null; then
        echo "${red}CRITICAL ERROR!!${reset} $dep is not installed or not in the PATH"
        exit 1
    fi
done

# Prompt the user to decide if they want to remove the original PNG files
echo "Do you want to remove the original PNG files after conversion? (y/n): "
read remove_files

# Convert the input to lowercase
remove_files=$(echo "$remove_files" | tr '[:upper:]' '[:lower:]')

if [ "$remove_files" != "y" ] && [ "$remove_files" != "n" ]; then
    echo "${red}Invalid input! Please enter 'y' or 'n'.${reset}"
    exit 1
fi

if [ ! "$1" ] && [ -p /dev/stdin ]; then
    set -- $(cat)
elif [ -z "$1" ]; then
    echo "${red}No files provided!${reset}"
    exit 1
fi

for file in "$@"; do
    [ -f "$file" ] || continue

    printf '[*] PROCESSING: %s\n' "$file"

    case "$file" in
        *.png)
            # Handle files with spaces by using double quotes around variables
            convert "$file" "${file%.png}.jpg" &&
            jpegoptim -s "${file%.png}.jpg"
            if [ "$remove_files" = "y" ]; then
                rm "$file"
            fi
            ;;
        *)
            >&2 printf 'Not a PNG file: %s\n' "$file"
    esac
done
