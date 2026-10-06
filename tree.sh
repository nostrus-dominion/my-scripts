#!/bin/bash
# Creates DISK0.tree, DISK1.tree, DISKx.tree inside each disk, with the output of tree command.
# After generating the report, it send via email using mail.
# To add more disks, just add DISK[x]=/full/path to the disk. Just make sure that the array index are sequencial.
# Why this?
# With the reports from tree, in case of disk failure, you will know which file got lost and you can recover them, downloading or via backups.
# GIST: https://gist.github.com/rafaelbiriba/0ee7ca2baec1ef80a878c825295f09e1

config_file="${MY_SCRIPTS_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts}/.env.tree"
if [ ! -r "$config_file" ]; then
  echo "Configuration file not found or unreadable: $config_file" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
. "$config_file"
set +a

: "${DISK_PATHS:?DISK_PATHS is required in $config_file}"
IFS=: read -r -a DISKS <<< "$DISK_PATHS"


# Dependency check.
dependencies=("mktemp" "date" "tree" "cat" "rm")
[[ -z ${EMAIL_ADDRESS:-} ]] || dependencies+=(/usr/bin/mail)
missing_dependencies=()
for dependency in "${dependencies[@]}"; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    missing_dependencies+=("$dependency")
  fi
done
if ((${#missing_dependencies[@]})); then
  for dependency in "${missing_dependencies[@]}"; do
    printf 'ERROR: Required command "%s" is not installed or not in PATH.\n' "$dependency" >&2
  done
  exit 1
fi

### DON'T CHANGE BELOW ###
email_output_tmp=$(mktemp)
date=$(date +"%Y-%m-%d")

for i in "${!DISKS[@]}"; do
  cd "${DISKS[$i]}" || exit 1
  echo "Disk tree report from $date" > "DISK$i.tree"
  echo "DISK$i - ${DISKS[$i]}" >> "DISK$i.tree"
  echo "=================================================================" >> "DISK$i.tree"
  tree -h >> "DISK$i.tree"
  cat "DISK$i.tree" >> "$email_output_tmp"
done

if [ -n "${EMAIL_ADDRESS:-}" ]; then
  /usr/bin/mail -s "Disk tree report from $date" "$EMAIL_ADDRESS" < "$email_output_tmp"
fi
rm -f "$email_output_tmp"
