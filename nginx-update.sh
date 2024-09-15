#!/bin/bash

# Version 0.3
# License: Open Source GPL
# Copyright: (c) 2024
# Dependencies: nginx (duh)

## CONSTANTS

# Global Variables for ANSI color
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Check if user has root privileges
if [ "$EUID" -ne 0 ]; then
    echo
    echo -e  ${red}"Please run as root!"${reset}
    echo
    exit 1
fi

# Check if Nginx is already installed
if [ -x "$(command -v nginx)" ]; then
    echo ""
    echo "Nginx is installed. Checking for updates..."
    echo ""
else
    echo
    echo -e ${red}"Nginx is not installed. Exiting script."${reset}
    echo
    exit 1
fi

# Get the latest version of Nginx
latest_version=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

# Get the currently installed version of Nginx
installed_version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9]+\.[0-9]+\.[0-9]+')

# Compare installed version with the latest version
if [ "$latest_version" != "$installed_version" ]; then
    echo -e "Installed version: ${yellow}$installed_version${reset}"
    echo -e "Latest version: ${yellow}$latest_version${reset}"
    echo ""
    read -p "Do you want to upgrade Nginx? (y/n): " upgradeChoice
    if [[ "$upgradeChoice" =~ ^[Yy]$ ]]; then

        # Backup current Nginx setup
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        backup_file="$user_home/nginx_backup_$(date +%Y%m%d%H%M%S).tar.gz"
        echo
        echo "Creating backup of the current Nginx setup at $backup_file..."
        sleep 3
        tar -czvf "$backup_file" /etc/nginx /usr/sbin/nginx /var/log/nginx /var/www/html

        # Download and upgrade Nginx
        echo
        echo "Downloading and installing $latest_version of nginx..."
        sleep 3
        wget "https://nginx.org/download/nginx-$latest_version.tar.gz" -P /tmp
        tar -zxvf "/tmp/nginx-$latest_version.tar.gz" -C /tmp
        cd "/tmp/nginx-$latest_version"
        ./configure
        make
        make install
        echo "Nginx upgraded to version $latest_version."
        sleep 3
        # Restart Nginx to apply changes
        echo "Attempting to restart nginx service..."
        service nginx restart
    else
        echo
        echo "Upgrade cancelled. Nginx will not be upgraded."
    fi
else
    echo -e "Nginx is already up to date (version ${yellow}$latest_version${reset}). No upgrade necessary."
    exit
fi
