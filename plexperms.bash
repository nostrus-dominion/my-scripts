#!/bin/bash

# Version 0.9
# License: GPL

LOGFILE="/var/log/script-logs/plexperms.log"
mkdir -p "$(dirname "$LOGFILE")"

# Redirect all output (stdout and stderr) to the log file
exec >> "$LOGFILE" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scanning and correcting file ownership and permissions..."

# Find all files/dirs that don't match user/group/permission criteria
changed_files=$(sudo find /mnt/plex/ \( ! -user plex -o ! -group plex -o \( -type d -a ! -perm 775 \) -o \( -type f -a ! -perm 755 \) \))

# Apply fixes
if [[ -n "$changed_files" ]]; then
  echo "$changed_files" | while read -r file; do
    echo "Fixing: $file"
    sudo chown plex:plex "$file"
    sudo chmod u+rwX,g+rwX,o+rX "$file"
    if [ -d "$file" ]; then
      sudo chmod 775 "$file"
    elif [ -f "$file" ]; then
      sudo chmod 755 "$file"
    fi
  done
  count=$(echo "$changed_files" | wc -l)
else
  echo "No changes needed."
  count=0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] $count file(s) changed."
echo "Exiting script."
