#!/bin/bash

# Used to extract archives from Deluge


formats=(zip rar)
commands=([zip]="7z e" [rar]="7z e")
extraction_subdir='extracted'

torrentid=$1
torrentname=$2
torrentpath=$3

cd "${torrentpath}"
for format in "${formats[@]}"; do
    while read file; do 
        cd "$(dirname "$file")"
        file=$(basename "$file")
        ${commands[$format]} "$file"
    done < <(find "$torrentpath/$torrentname" -iname "*.${format}" )
done
