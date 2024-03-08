#!/bin/bash

#Version 0.6

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

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
