#!/bin/bash

read -p "Enter the session string: " session_string

output=$(curl -s -c /path/docker/persists/mam.cookies -b "mam_id=$session_string" https://t.myanonamouse.net/json/dynamicSeedbox.php)

echo "$output"
