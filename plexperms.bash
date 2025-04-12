#!/bin/bash

# Version 0.7
# License: GPL

sudo find . \( ! -user plex -o ! -group plex -o \( -type d -a ! -perm 775 \) -o \( -type f -a ! -perm 755 \) \) \
  -exec chown -v plex:plex {} + \
  -exec chmod -v u+rwX,g+rwX,o+rX {} + \
  -exec test -d {} \; -exec chmod -v 775 {} + \
  -exec test -f {} \; -exec chmod -v 755 {} +
