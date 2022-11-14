#!/bin/bash
#This script is designed to be used to download
#dropbox links directly in the CLI if you need
#to. Written by Paul Musselman 2022/11/14.

read -rp "Paste Dropbox Link: " URL

curl -L "$URL" -o download.zip

sleep 1

7z x download.zip

sleep 1

rm download.zip

echo "DONE!"
