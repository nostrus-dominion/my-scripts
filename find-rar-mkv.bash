#!/bin/bash

find . -type d -exec bash -c '
    for dir in "$@"; do
        find "$dir" -maxdepth 1 -type f -name "*.rar" -o -name "*.zip" |
        while read file; do
            base_name=$(basename "$file" .rar)
            base_name=$(basename "$base_name" .zip)
            if [ -f "$dir/${base_name}.mkv" ]; then
                echo "Found matching files: $file and $dir/${base_name}.mkv"
            fi
        done
    done
' bash {} + | sort
