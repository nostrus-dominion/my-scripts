#!/bin/bash

echo "Enter the desired date and time (YYYY-MM-DD HH:MM:SS):"
read target_datetime

find . -type f -o -type d | while IFS= read -r item
do
  touch -d "$target_datetime" "$item"
done
