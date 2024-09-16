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
deps=("tar" "unzip" "unrar" "7z")
for dep in "${deps[@]}"; do
    if ! which "$dep" > /dev/null; then
        echo "${red}CRITICAL ERROR!!${reset} $dep is not installed or not in the PATH"
        exit 1
    fi
done

usage() {
    >&2 printf '%s\n' "Usage: ${0##*/} [-c copy_path] file"
    exit 1
}

decompress() {
    case ${1##*.} in
        gz|tgz)   gunzip -qdc "$1" ;;
        xz|txz)   xz -qdcT 0 "$1"  ;;
        bz2|tbz)  bunzip2 -qdc "$1" ;;
        zst|zstd) zstd -dqc "$1" ;;
        lz4)      lz4 -dqc "$1"
    esac
}

run() {
    case $1 in
        *tar.*|*.tgz|*.txz|*.tbz)
            decompress "$1" | \
            tar -C "${COPY_PATH:-$PWD}" -xpf -
            ;;
        *.xz|*.gz|*.bz2|.zstd|.zst|.lz4)
            decompress "$1" "${COPY_PATH:-$PWD}/${1%.*}"
            ;;
        *.zip)
            unzip -q "$1" -d "$2"
            ;;
        *.rar)
            unrar x "$1"
            ;;
        *.7z)
            7z x "$1"
            ;;
        *.tar)
            tar -C "${COPY_PATH:-$PWD}" -xpf "$1"
            ;;
        *)
            >&2 echo "Unrecognized compression format: ${1##*.}"
    esac
}

while [ "$1" ] ; do
    case $1 in
        -h|h)
            usage
            ;;
        -C|-c)
            COPY_PATH=$1
            ;;
        *)
            run "$@"
    esac
    shift
done
