#!/bin/sh

find . -name "*.m4a" -exec bash -c 'for f'; do ffmpeg -i "$f" -acodec libmp3lame -b:a 320k "${f%.*}.mp3"; done' -- {} + 
