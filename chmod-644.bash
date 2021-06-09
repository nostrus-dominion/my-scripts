#!/bin/bash

# Will change the files within the current directory and 
# all sub directories to w/r for the creator with r only.

find . -type f -exec chmod 644 -- {} +
