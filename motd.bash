#!/bin/bash

## Version 0.1
## License: Open Source GPL
## Copyright: (c) 2023

for f in /etc/update-motd.d/* ; do
        bash "$f"
done
