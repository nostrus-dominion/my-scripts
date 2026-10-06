#!/bin/bash

############
### Version 0.7
### License: Open Source GPL
### Copyright: (c) 2024
############

#######################
## ALL THE BORING STUFF
#######################

# Dependency check.
dependencies=("grep" "curl" "sed" "service")
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

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

##################
## START OF SCRIPT
##################

# Get the current IP address from vsftpd.conf
current_ip=$(grep -oP 'pasv_address=\K[^ ]+' /etc/vsftpd.conf)

# Get the new IP address using curl
new_ip=$(curl -s icanhazip.com)

# Compare the current and new IP addresses
if [ "$current_ip" != "$new_ip" ]; then
  # Update vsftpd.conf with the new IP address
  sed -i "s/pasv_address=$current_ip/pasv_address=$new_ip/" /etc/vsftpd.conf

  # Restart vsftpd service (adjust the command based on your system)
  service vsftpd restart

  echo "IP address has been updated in vsftpd.conf. Restarted vsftpd service."
else
  echo "IP addresses match. No update needed."
fi
