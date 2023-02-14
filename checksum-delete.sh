#!/bin/bash
#Originally created by SiegeX in superuser.com from 
#this thread. https://superuser.com/questions/386199
#/how-to-remove-duplicated-files-in-a-directory
#
#I switched it from md5sum to sha256 and actually made
#it delete files.

declare -A arr
shopt -s globstar

for file in **; do
  [[ -f "$file" ]] || continue
  
  read cksm _ < <(sha256sum "$file")
  if ((arr[$cksm]++)); then 
    rm $file
    echo "Deleted $file"
  fi
done
