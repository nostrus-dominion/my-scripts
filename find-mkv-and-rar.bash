#!/bin/bash

#This script is designed for a seedbox to seek
#and destroy an *.mkv file that has a *rar file 
#in the same directory to save space on a seedbox.

find . -type -f -name '*.mkv' -exec bash -c '[ -f "${1%.*}.rar" ] && echo "$1"' _ {} \;