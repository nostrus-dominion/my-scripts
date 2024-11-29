#!/bin/bash

# Version 0.7

# Default directory
DIRECTORY="/mnt/thevault/"

# Check for -pwd flag
if [ "$1" == "-pwd" ]; then
  DIRECTORY=$(pwd)
fi

sudo find "$DIRECTORY" -path "$DIRECTORY/Nginx-Fancyindex-Theme-dark" -prune -o \
  \( ! -user pmusselman -o ! -group pmusselman -o \
  \( -type d -a ! -perm 775 \) -o \
  \( -type f -a ! -perm 755 \) \) \
  -exec chown -v pmusselman:pmusselman {} + \
  -exec chmod -v u+rwX,g+rwX,o+rX {} + \
  -exec test -d {} \; -exec chmod -v 775 {} + \
  -exec test -f {} \; -exec chmod -v 755 {} +
