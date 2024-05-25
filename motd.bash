#!/bin/bash

## Version 0.2
## License: Open Source GPL
## Copyright: (c) 2023

for f in /etc/update-motd.d/* ; do
    if [ -x "$f" ]; then
        bash "$f"
    fi
done
