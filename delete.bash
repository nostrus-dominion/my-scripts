#!/bin/bash

# Designed to delete files of a specified extension permanetely.

echo -e "WARNING!! THESE DELETIONS ARE PERMANENT!!"

echo -e "DO NOT USE THIS UNLESS YOU'RE 100% SURE!!"

sleep 2s

echo -e "File Extension to Delete: "

read -r EXT

echo -e "Five second countdown to [CTRL-C] to cancel"

for i in {5..1};do echo -n "$i." && sleep 1; done

echo -e "Deleting all ${EXT}"

find . -name "*.${EXT}" -exec rm -rf {} \;

echo -e "Finished!"
