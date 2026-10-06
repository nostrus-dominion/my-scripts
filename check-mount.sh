#!/bin/bash

#Checks remote mounts 
#Created May 15 2018
#Modified July 15 2018

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

config_file="${MY_SCRIPTS_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts}/.env.check-mount"
if [ ! -r "$config_file" ]; then
  echo "Configuration file not found or unreadable: $config_file" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
. "$config_file"
set +a

: "${MOUNT_PATHS:?MOUNT_PATHS is required in $config_file}"
: "${MOUNT_CHECK_FILES:?MOUNT_CHECK_FILES is required in $config_file}"
IFS=: read -r -a mount_paths <<< "$MOUNT_PATHS"
IFS=: read -r -a check_files <<< "$MOUNT_CHECK_FILES"

if [ "${#mount_paths[@]}" -ne "${#check_files[@]}" ]; then
  echo "MOUNT_PATHS and MOUNT_CHECK_FILES must contain the same number of entries." >&2
  exit 1
fi

for i in "${!mount_paths[@]}"; do
  if [ -f "${check_files[$i]}" ]; then
    echo "OK: ${mount_paths[$i]}"
  else
    mount -o "${MOUNT_OPTIONS:-uid=plex,gid=plex}" "${mount_paths[$i]}"
    echo "Remounted ${mount_paths[$i]}"
  fi
done
