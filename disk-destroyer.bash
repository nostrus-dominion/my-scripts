#!/bin/bash

## disk-destroyer is a simple script that will erase a selected drive with
## either zeros or random bits while using dcfldd (which is dd on steroids).
## DISCLAIMER: I used both ChatGPT and Copilot to check my work.

# Version 0.9
# License: Open Source GPL
# Copyright: (c) 2024
# Dependencies: dcfldd

## CONSTANTS

# Global Variables for ANSI color
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
reset=$(tput sgr0) # No Color

## SCRIPT CHECKING PRIVILEGES AND DEPENDENCIES

# Check if user has root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo
  echo -e "${red}Please run as root!${reset}"
  echo
  exit 1
fi

# Checking if dependencies are installed
dependencies=("dcfldd" "pv")
for cmd in "${dependencies[@]}"; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo -e "${red}ERROR:${reset} The command ${red}'$cmd'${reset} is not installed, quitting :(" >&2
    exit 1
  fi
done

### ACTUAL START OF THE SCRIPT
clear
# Title splash
echo ${orange}""
echo -e "                       ____  _________ __ __             "
echo -e "                      / __ \/  _/ ___// //_/             "
echo -e "                     / / / // / \__ \/ ,<                "
echo -e "                    / /_/ // / ___/ / /| |               "
echo -e "      ____  _______/_____/___//____/_/_|_| ____________  "
echo -e "     / __ \/ ____/ ___/_  __/ __ \/ __ \ \/ / ____/ __ \ "
echo -e "    / / / / __/  \__ \ / / / /_/ / / / /\  / __/ / /_/ / "
echo -e "   / /_/ / /___ ___/ // / / _, _/ /_/ / / / /___/ _, _/  "
echo -e "  /_____/_____//____//_/ /_/ |_|\____/ /_/_____/_/ |_|   "
echo -e ""
echo -e " This script is to systematically erase a disk or block  "
echo -e " device local to this machine. Please be sure of which. " ${reset}

echo ""
echo "Here are the block devices:"
# Generate a list of block devices and assign alphabetic labels
block_devices=$(lsblk -o NAME,TYPE,SIZE,PARTLABEL,MOUNTPOINT -p -n | awk '$2 == "disk" {print $1, $3}' | sort)
device_labels=()
device_map=()
i=0

# Check if the block_devices variable is empty
if [ -z "$block_devices" ]; then
    echo -e "${red}No block devices found!${reset}"
    exit 1
fi

# Iterate over block devices and assign labels
while IFS= read -r line; do
    device=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    letter=$(echo | awk -v i=$i '{printf "%c", 97+i}')  # '97' is ASCII for 'a'
    echo -e "$letter) $device ($size)"
    device_labels+=("$letter")
    device_map["$letter"]="$device"
    ((i++))
done <<< "$block_devices"
echo ""

# Device selection and verification
while true; do
    echo
    read -r -p "Enter the letter of the device to wipe (e.g., a, b, c): " choice
    if [ "$choice" = "exit" ]; then
        echo "Exiting script! Goodbye!"
        exit 0
    elif [[ ! " ${device_labels[@]} " =~ " $choice " ]]; then
        echo
        echo -e "${red}Error! '$choice' is not a valid selection. Exiting script.${reset}"
        exit 1
    else
        disk=${device_map["$choice"]}
        break
    fi
done
echo
echo "Selected device: $disk"

# Define array for block sizes
block_choices=("512" "1K" "2K" "4K" "8K")

# Prompt user for block size choice
echo ""
echo "Please select a block size for your device:"
select blocksize in "${block_choices[@]}"; do
    case $blocksize in
        *)
            echo ""
            echo "You have selected: ${blocksize}"
            break
            ;;
    esac
done

# Define array for fill types
fill_types=("zero" "one" "random")

# Prompt user for fill type choice
echo ""
echo "Choose fill type:"
select fill_choice in "${fill_types[@]}"; do
    case $fill_choice in
        *)
            echo ""
            echo "You have selected: ${fill_choice}"
            break
            ;;
    esac
done

### User confirmation for destroying disk
echo
echo -e "${yellow}!!!SANITY CHECK!!!${reset}"
echo
echo "You are about to completely destroy all of the data within the"
echo "device ${yellow}$disk${reset}. Are you absolutely SURE you wish to continue?"
read -r -p "Type 'yes' to proceed with disk destruction or any other input to quit: " confirmation
if [ "$confirmation" = "yes" ]; then
    echo ""
    echo -e "I don't think you understand what you just agreed too..."
else
    echo ""
    echo -e "Operation cancelled! Exiting script!"
    exit 1
fi

### Second user confirmation for destroying disk
echo
echo -e "${yellow}!!!ABSOLUTELY SURE SANITY CHECK!!!${reset}"
echo
echo "Are you really REALLY REALLY sure you wish to continue?"
read -r -p "Type 'destroy' to proceed with disk destruction or any other input to quit: " confirmation
if [ "$confirmation" = "destroy" ]; then
    echo ""
    echo -e "Proceeding with the destruction of $disk..."
else
    echo ""
    echo -e "Operation cancelled! Exiting script!"
    exit 1
fi

# Extract numerical value from blocksize
blocksize_value=$(echo "$blocksize" | tr -d '[:alpha:]')
if [[ "$blocksize" =~ K$ ]]; then
    blocksize_value=$((blocksize_value * 1024))
elif [[ "$blocksize" =~ M$ ]]; then
    blocksize_value=$((blocksize_value * 1024 * 1024))
fi

# Get total size of the disk
total_size=$(lsblk -b -o SIZE -n -p $disk | awk '{print $1}')
total_blocks=$((total_size / blocksize_value))
time_estimate_seconds=$((total_blocks / 10000))  # Assuming average speed of 10 MB/s
time_estimate_minutes=$((time_estimate_seconds / 60))
echo ""
echo "Estimated time for completion: approximately $time_estimate_minutes minutes."

# Run dcfldd based on fill type
case $fill_choice in
    zero)
        dcfldd if=/dev/zero of=$disk bs=$blocksize status=on statusinterval=1024
        ;;
    one)
        dcfldd if=/dev/urandom of=$disk bs=$blocksize status=on statusinterval=1024
        ;;
    random)
        dcfldd if=/dev/urandom of=$disk bs=$blocksize status=on statusinterval=1024
        ;;
esac

sync
echo "It is done. Hope you were sure."
exit 0
