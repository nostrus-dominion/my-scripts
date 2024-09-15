#!/bin/bash

## Version 2.3
## V1 Created 2024-09-15
## License: Open Source GPL
## Copyright: (c) 2024

## ALL THE BORING STUFF

# Global Variables for ANSI color
red=$(tput setaf 1)
brown=$(tput setaf 166)
reset=$(tput sgr0)

# Checking if dependencies are installed
deps=("openssl" "sha256sum")
for dep in "${deps[@]}"; do
    if ! which "$dep" > /dev/null; then
        echo -e "${red}CRITICAL ERROR!! $dep is not installed or not in the PATH${reset}"
        exit 1
    fi
done

## FUNCTIONS

# Function to display usage information
usage() {
    >&2 cat <<EOF
${0##*/} - A script to encrypt or decrypt a file using OpenSSL.

Usage:
---------
${0##*/} [-s] file                encrypt a file (with checksum)
${0##*/} [-sd] file.crypt         decrypt a file (with checksum verification)
${0##*/} [-d] file.crypt          decrypt a file (without checksum verification)

EOF
    exit 1
}

# Function to check if a file exists
isfile() {
    [ -f "$1" ] || usage
}

# Function to generate a random filename
get_entropy() {
    LC_ALL=C \
    tr -dc -- A-Z-a-z-0-9 < /dev/urandom 2>/dev/null | \
    dd ibs=1 obs=1 count=8 2>/dev/null | \
    sed 's/\-//g' 2>/dev/null || printf '%s\n' $$
}

# Function to encrypt a file
encrypt() {
    local infile="$1"
    local outfile="${infile}.crypt"
    local checksum_file="${outfile}.sha256"

    # Encrypt the file
    openssl enc -aes-256-cbc -a -salt -pbkdf2 -in "$infile" -out "$outfile" || die "Failed to encrypt '$infile'"

    if [ "$include_checksum" = true ]; then
        # Generate checksum
        sha256sum "$outfile" | awk '{ print $1 }' > "$checksum_file"
        echo "Checksum saved as '$checksum_file'"
    fi

    echo "File encrypted as '$outfile'"
}

# Function to decrypt a file
decrypt() {
    local infile="$1"
    local outfile="${infile%.crypt}"
    local checksum_file="${infile}.sha256"

    if [ "$include_checksum" = true ]; then
        # Verify checksum
        if [ -f "$checksum_file" ]; then
            local original_checksum=$(cat "$checksum_file")
            local current_checksum=$(sha256sum "$infile" | awk '{ print $1 }')

            if [ "$original_checksum" != "$current_checksum" ]; then
                die "Checksum verification failed for '$infile'. File may be corrupted."
            fi
        else
            echo "Checksum file '$checksum_file' not found. Skipping verification."
        fi
    fi

    # Decrypt the file
    openssl enc -aes-256-cbc -d -a -salt -pbkdf2 -in "$infile" -out "$outfile" || die "Failed to decrypt '$infile'"
    echo "File decrypted as '$outfile'"
}

# Function to handle script termination
die() {
    >&2 printf '%s\n' "$*"
    exit 1
}

## BEGINNING OF SCRIPT

# Default value for checksum inclusion
include_checksum=false

# Main function
main() {
    while getopts ":sd" opt; do
        case ${opt} in
            s)
                include_checksum=true
                ;;
            d)
                decrypt_mode=true
                ;;
            \?)
                usage
                ;;
        esac
    done
    shift $((OPTIND -1))

    if [ "$decrypt_mode" = true ]; then
        shift
        case ${1#-} in
            i)
                shift
                isfile "$1" || usage
                tmp=/tmp/$$-$(get_entropy).decrypt
                decrypt "$1" > "$tmp" || die "couldn't decrypt to '$tmp'"
                mv -f -- "$tmp" "${1%.crypt}" || die "couldn't name '$tmp' to '${1%.crypt}'"
                rm -f -- "$1"
                ;;
            *)
                isfile "$1" || usage
                decrypt "$1"
        esac
    else
        isfile "$1" || usage
        encrypt "$1"
    fi
}

main "$@"
