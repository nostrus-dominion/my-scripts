#!/bin/bash

## disk-destroyer is a simple script that will erase a selected drive with
## either zeros or random bits while using dcfldd (which is dd on steriods).
## DISCLAIMER: I used both ChatGPT and Copilot to check my work.

# Version 0.1
# License: Open Source GPL
# Copyright: (c) 2024
# Dependacies: dcfldd

## ALL THE BORING STUFF

# Global Variables for ANSI color
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
cyan='\033[0;36m'
brown='\033[0;33m'
reset='\033[0m' # No Color

## SCRIPT CHECKING PRIVILEGES AND DEPENDACIES

# Check if user has root privileges
if [ "$EUID" -ne 0 ]; then
  echo
  echo -e ${red}"Please run as root!"${reset}
  echo
  exit
fi

### FUNCTIONS

# Function to check for and install missing dependencies
check_dependencies() {
    local deps=("dcfldd")

    echo ""
    echo -e "${yellow}Checking for dependencies...${reset}"

    local missing_packages=()
    for pkg in "${deps[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo ""
        echo -e "${green}All required packages are installed!${reset}"
    else
        echo ""
        echo -e "Installing missing prerequisite packages: ${brown}${missing_packages[*]}${reset}"
        # Install missing prerequisite packages
        apt update > /dev/null 2>&1 && apt install -y "${missing_packages[@]}" > /dev/null 2>&1

        local failed_packages=()
        # Check if the packages were installed successfully
        for pkg in "${missing_packages[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                failed_packages+=("$pkg")
            fi
        done

        if [ ${#failed_packages[@]} -eq 0 ]; then
            echo ""
            echo -e "${green}All missing prerequisite packages installed successfully!${reset}"
        else
            echo ""
            echo -e "${red}Failed to install some of the prerequisite packages:${reset} ${brown}${failed_packages[*]}${reset}"
            exit 1
        fi
    fi
}

check_dependencies

sleep 10

#accepts "zero" or "random" as line arguments; will be used with /dev/ later...
type=$1

#default to zero if no input
if [ -z $type ]
	then type=zero
	else break
fi

clear

### ACTUAL START OF THE SCRIPT

# Title splash
echo ""
echo "                     ____  _________ __ __             "
echo "                    / __ \/  _/ ___// //_/             "
echo "                   / / / // / \__ \/ ,<                "
echo "                  / /_/ // / ___/ / /| |               "
echo "    ____  _______/_____/___//____/_/_|_| ____________  "
echo "   / __ \/ ____/ ___/_  __/ __ \/ __ \ \/ / ____/ __ \ "
echo "  / / / / __/  \__ \ / / / /_/ / / / /\  / __/ / /_/ / "
echo " / /_/ / /___ ___/ // / / _, _/ /_/ / / / /___/ _, _/  "
echo "/_____/_____//____//_/ /_/ |_|\____/ /_/_____/_/ |_|   "
echo ""

echo Here are the block devices:
echo $(ls /dev/sd* | sed 's/[0-9]*$//' | sort -u )
echo
echo Your system disk is:
echo $(lsblk -oMOUNTPOINT,PKNAME -P | grep 'MOUNTPOINT="/"' | sed 's/[0-9]*$//')
echo
#wait for input $disk
read -r -p "Enter device to wipe:" disk

blocksize=$(blockdev --getpbsz $disk)

if [ -z $blocksize ]
then
	echo No blocksize. Try to run as root.
	exit
fi

#echo $type $disk $blocksize

echo !!!SANITY CHECK!!!
echo You are about to $type fill $disk with $blocksize bytes per block.
read -p "Are you sure? " yn
case $yn in
	[nN] ) echo Nothing Happened. && exit;;
	[yY] ) echo DESTROY ;
		dcfldd if=/dev/$type of=$disk bs=$blocksize status=on statusinterval=1024;
    sync;
    echo It is done.;
    exit;;
	* ) echo Something went wrong;;
esac

echo It is done.

