#!/bin/bash

## Version 0.3
## License: Open Source GPL
## Copyright: (c) 2026

if [ $(id -u) -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

for f in /etc/update-motd.d/* ; do
    if [ -x "$f" ]; then
        bash "$f"
    fi
done
