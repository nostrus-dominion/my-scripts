#!/bin/bash

#Download directory
SAVEPATH="/dump/.pillage/${1-$currentdir}"

#Save link adresses to /home/*/.pillager/list
echo -n "URL to pillage: "

read -r URL

echo "$URL"
wget -r -np -nc -e robots=off -c --reject index.html,index.html* "${URL}" -P "$SAVEPATH"

echo "Finished. Yar."