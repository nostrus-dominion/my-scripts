#!/bin/bash

# Version 0.4

find /mnt/thevault -path '/mnt/thevault/Nginx-Fancyindex-Theme-dark' -prune -o \( ! -perm 775 -type d \) -o \( ! -perm 755 -type f \) -exec chmod -- {} +
