#!/bin/bash

#This script was created to clean up massive
#amounts of files wihtin a directory who have
#horrible naming schemes. Used for internet
#downloads and shit.

ls -1prt | grep -v "/$" | cat -n | while read n f; do mv -n "${f}" "$(printf "%03d" $n).${f#*.}"; done
