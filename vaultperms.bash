#!/bin/bash

# Version 0.6

sudo find /mnt/plex -path '/mnt/thevault/Nginx-Fancyindex-Theme-dark' -prune \( ! -user pmusselman -o ! -group pmusselman -o \( -type d -a ! -perm 775 \) -o \( -type f -a ! -perm 755 \) \) -exec chown -v pmusselman:pmusselman {} + -exec chmod -v u+rwX,g+rwX,o+rX {} + -exec test -d {} \; -exec chmod -v 775 {} + -exec test -f {} \; -exec chmod -v 755 {} +
