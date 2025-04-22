#!/bin/bash

# Version 0.5
# License: Open Source GPL
# Copyright: (c) 2024
# Dependencies: nginx (duh)

## CONSTANTS

# Global Variables for ANSI color
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0) # No Color

# Exit immediately if a command exits with a non-zero status
set -e

# Check if user has root privileges
if [ "$EUID" -ne 0 ]; then
    echo
    echo "This script must be run as root. Please prefix the command with 'sudo'."
    echo
    exit 1
fi

# Check if required commands are available
for cmd in curl wget tar make gcc; do
    if ! command -v "$cmd" &> /dev/null; then
		echo
        echo "${red}Error!${reset} Required command ${yellow}'$cmd'${reset} is not installed. Please install it and try again."
        echo
        exit 1
    fi
done

# Check if Nginx is already installed
if ! command -v nginx &> /dev/null; then
    echo
    echo "Error: Nginx is not installed. Please install it first."
    echo
    exit 1
fi

# Fetch the latest Nginx version
latest_version=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ -z "$latest_version" ]; then
	echo
    echo "Error: Unable to fetch the latest Nginx version. Please check your internet connection or the Nginx website."
    echo
    exit 1
fi

# Get the currently installed version
installed_version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9]+\.[0-9]+\.[0-9]+')

# Compare versions and perform upgrade if necessary
if [ "$latest_version" != "$installed_version" ]; then
    echo "Installed version: $installed_version"
    echo "Latest version: $latest_version"
    read -p "Do you want to upgrade Nginx? (y/n): " upgradeChoice
    if [[ "$upgradeChoice" =~ ^[Yy]$ ]]; then
        # Backup current Nginx setup
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        backup_file="$user_home/nginx_backup_$(date +%Y%m%d%H%M%S).tar.gz"
        echo "Creating backup at $backup_file..."
        tar -czvf "$backup_file" /etc/nginx /usr/sbin/nginx /var/log/nginx /var/www/html || {
            echo "Error: Failed to create backup."
            exit 1
        }

        # Download and upgrade Nginx
        echo "Downloading and installing Nginx $latest_version..."
        wget "https://nginx.org/download/nginx-$latest_version.tar.gz" -P /tmp
        tar -zxvf "/tmp/nginx-$latest_version.tar.gz" -C /tmp
        cd "/tmp/nginx-$latest_version" || exit
        ./configure
        make
        make install

        # Restart Nginx service
        if command -v systemctl &> /dev/null; then
            systemctl restart nginx
        else
            service nginx restart
        fi

        echo "Nginx upgraded to version $latest_version."
    else
        echo "Upgrade cancelled. Nginx will not be upgraded."
    fi
else
    echo "Nginx is already up-to-date (version $latest_version)."
fi
