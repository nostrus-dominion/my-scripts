#!/bin/bash

# Version 0.5
# License: GPL

sudo find /mnt/plex \( ! -user plex -o ! -group plex \) -exec chown -R plex:plex -- {} +

sudo find /mnt/plex \( ! -perm 775 -type d \) -exec chmod 775 -- {} +

sudo find /mnt/plex \( ! -perm 755 -type f \) -exec chmod 755 -- {} +
