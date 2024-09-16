#!/bin/bash

# Version 0.4

# Prune the specific path
find /mnt/thevault -path '/mnt/thevault/Nginx-Fancyindex-Theme-dark' -prune -o \( -type d \! -perm 775 \) -print0 | xargs -0 chmod 775
find /mnt/thevault -path '/mnt/thevault/Nginx-Fancyindex-Theme-dark' -prune -o \( -type f \! -perm 755 \) -print0 | xargs -0 chmod 755
