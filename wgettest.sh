#!/bin/bash
# shitty script to download and rename individual files with wget

currentdir="$PWD"
SAVEPATH="${1:-$currentdir}"

sleep 1

read -rp "Please paste URL: " URL

sleep 1

read -rp "Enter new file name: " NAME

wget -r -nc -np -e robots=off -c --reject index.html,index.html* "${URL}" -O "$NAME" -P "$SAVEPATH"

echo "Download and rename completed"

exec "$HOME/scripts/wgetrename.sh"