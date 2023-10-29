#!/bin/bash

for f in /etc/update-motd.d/* ; do
        bash "$f"
done
