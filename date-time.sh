#!/bin/bash

echo "Enter the desired date and time (YYYY-MM-DD HH:MM:SS):"
read target_datetime

total_items=$(find . -type f -o -type d | wc -l)
current_item=0

find . -type f -o -type d | while IFS= read -r item

do
  current_item=$((current_item + 1))
  percentage_complete=$((100 * current_item / total_items))
  echo -ne "\rChanging creation date of items... $percentage_complete% complete"

  touch -d "$target_datetime" "$item"
done

echo -ne "\n"
