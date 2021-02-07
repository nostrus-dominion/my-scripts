#!/bin/bash

# FFMERG
# Version 0.5
# License: Open Source (GPL)
# Copyright: (c) 2021
# Dependancy: ffmpeg, bash

# This script is designed to merge all files of the same codec and extension (ex. mp3, m4a, mp4, mkv)
# in the working directory using FFMPEG. It is required that all the files be from the same source,
# with the same containers, codec, dimensions (etc). Files from a different source or codec will fail
# and cannot be merged.

echo -e "WARNING! PLEASE BE SURE THAT ALL MEDIA IS OF THE SAME CODEC/CONTAINER!"
echo -e "THIS SCRIPT WILL NOT WORK IF YOUR MEDIA IS FROM DIFFERENT SOURCES!"

sleep 2s

echo -e "Please enter the file extension of your media:"

read -r EXT

echo -e "Please enter the name of the output:"

read -r OUT

echo -e "Five second countdown to [CTRL-C] to cancel"

for i in {5..1};do echo -n "$i." && sleep 1; done

for f in ./*.$EXT; do echo "file '$f'" >> list.txt; done

ffmpeg -f concat -safe 0 -i list.txt -c copy "$OUT.$EXT"

rm list.txt

echo -e "DONE!"
