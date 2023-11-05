#!/bin/bash

#This script was taken from a thread on stackoverflow.
#You can find it here:
#https://stackoverflow.com/questions/11818408/convert-all-file-extensions-to-lower-case

find . -name '*.*' -type f -exec bash -c 'base=${0%.*} ext=${0##*.} a=$base.${ext,,}; [ "$a" != "$0" ] && mv -- "$0" "$a"' {} \;
