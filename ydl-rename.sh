#!/bin/bash

currentdir="$PWD"
FILENAME="${1:-$currentdir}"

read -p "Please paste your video URL: " URL

read -p "Enter name of the studio: " STUDIO

read -p "Enter name of the star(s): " STAR

echo "Download will now start"

youtube-dl -f best -o "[$STUDIO]-$STAR-%(title)s.%(ext)s" ${URL} --restrict-filenames 

echo "Download and rename completed"

exec "~/scripts/ydl-rename.sh"