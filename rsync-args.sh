#!/bin/bash

rsync -r --progress --chmod=770 --chown=plex:plex --ignore-existing --size-only --include="*/" --include="*.mkv" --exclude="*"
