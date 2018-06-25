#!/bin/bash

# Originally created by theaquacadet on github
# Edited by Paul Musselman on Nov. 19, 2017

[[ -d $HOME/.pillager ]] || mkdir "$HOME"/.pillager

# Download directory

currentdir="$PWD"
SAVEPATH="${1-$currentdir}"

#Save link adresses to /home/*/.pillager/list

list=$HOME/.pillager/list
echo -n "Link to pillage: "

read -r LINK

echo "$LINK" >> "$list"

wget -r -nH -np -nc -e robots=off -c --reject html,tmp "${LINK}" -P "$SAVEPATH"

echo "Finished. Yar."
