#!/bin/bash

#This script shows all filetypes from this directory
#into all subdirectories. I actually have no idea
#why I made this stupid waste of compute power.

find . -type f | grep -i -E -o "\.\w*$" | sort | uniq -c
