#!/bin/bash

#Version 0.1
#License: Open Source (GPL)
#Copyright: (c) 2023

# Find all filetypes, count them, and format output in multiple columns
filetypes=$(find . -type f | grep -i -E -o "\.\w*$" | sort | uniq -c | awk '{printf "%-17s %s\n", $2, $1}')
total_files=$(find . -type f | wc -l)

# Display filetypes in columns
echo -e "Filetype\tCount\n$filetypes"

# Display total number of files found
echo -e "\nTotal number of files found: $total_files"
echo -e
