#!/bin/bash

## Version 1.0
## Created 2024-09-15
## License: Open Source GPL
## Copyright: (c) 2024

## GLOBAL VARIABLES

# Color variables for output
red=$(tput setaf 1)
reset=$(tput sgr0)

# Check for dependencies
deps=("find")
for dep in "${deps[@]}"; do
    if ! command -v "$dep" > /dev/null; then
        echo -e "${red}CRITICAL ERROR!! $dep is not installed or not in the PATH${reset}"
        exit 1
    fi
done

# FUNCTIONS

# Function to display usage information
usage() {
    >&2 cat <<"EOF"
search - a tiny posix search function
===============================================
Usage: search.sh <f/d> <dir> [SEARCH TERMS]

[-f]    Search for a file (default)
[-d]    Search for a directory

Examples:
===============================================
1. Search for a file named "foo.txt"
$ search foo.txt

2. Search for a directory named "bar.d" in /etc
$ search -d /etc bar.d
EOF
    exit 1
}

# Function to validate the provided path
validate_path() {
    local path=$1
    if [ ! -d "$path" ]; then
        echo "Error: The provided path is not a directory."
        exit 1
    fi
}

# Function to parse arguments
parse_arguments() {
    while [ "$1" ]; do
        case ${1#-} in
            h)
                usage
                ;;
            f|d)
                search_type="-type $1"
                shift
                ;;
            *)
                if [ $# -eq 2 ]; then
                    if [ -d "$1" ]; then
                        search_dir="$1"
                        shift
                    else
                        usage
                    fi
                elif [ $# -eq 1 ]; then
                    search_dir="."
                else
                    usage
                fi
                search_term="$1"
                break
                ;;
        esac
        shift
    done

    # Default values
    [ -z "$search_type" ] && search_type="-type f"
    [ -z "$search_dir" ] && search_dir="."
    [ -z "$search_term" ] && usage
}

# Function to show a spinning animation while waiting
show_spinner() {
    local pid=$1
    local spinner="|/-\\"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\rSearching ${spinner:i++%${#spinner}:1}"
        sleep 0.1
    done
    echo -ne "\rDone!         \n"
}

## BEGINNING OF SCRIPT

# Parse command-line arguments
parse_arguments "$@"

# Validate the provided directory path
validate_path "$search_dir"

# Temporary file for search results
temp_file=$(mktemp)

# Show dots animation in the background and save the PID
{
    find -L "$search_dir" ! -path "$search_dir" $search_type -iname "*${search_term}*" -maxdepth 10 2>/dev/null > "$temp_file"
} &
dots_pid=$!
show_spinner "$dots_pid"

# Ensure the background process has finished before proceeding
wait "$dots_pid"

# Read and sort the results from the temporary file
sorted_results=$(sort "$temp_file")

# Output the findings to a .txt file in the $HOME directory
output_file="$HOME/search_results_$(date +%Y%m%d_%H%M%S).txt"
echo "$sorted_results" > "$output_file"
echo "Search results saved to $output_file"

# Cleanup temporary file
rm "$temp_file"

exit 0
