#!/bin/bash

## Version 0.5
## License: Open Source GPL
## Copyright: (c) 2023

## COLORS
green=$(tput setaf 2)
red=$(tput setaf 1)
reset=$(tput sgr0) # No color

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "${red}Please run as root!${reset}"
    echo ""
    exit 1
fi

# Function to display the current check state and progress with color formatting
display_status() {
  local status_output
  status_output=$(mdadm --detail /dev/md0)

  echo "$status_output" | while read -r line; do
    if echo "$line" | grep -q "State"; then
      if echo "$line" | grep -q "clean, checking"; then
        echo "${green}$line${reset}" # Green color for "clean, checking"
      else
        echo "$line"
      fi
    elif echo "$line" | grep -q -E 'Rebuild Status|Resync Status'; then
      echo "$line"
    fi
  done
}

# Display the current check state and progress
echo "Current status of /dev/md0:"
display_status
echo ""

#Execute writing to sync_action
while true; do
    # Display menu to the user
    echo "Select the action for /sys/block/md0/md/sync_action:"
    echo "1. Write 'idle'"
    echo "2. Write 'check'"

    # Read user choice
    read -p "Enter choice [1 or 2]: " choice

    case $choice in
        1)
            echo "idle" > /sys/block/md0/md/sync_action
            echo "'idle' has been written to /sys/block/md0/md/sync_action."
            break # Exit the loop
            ;;
        2)
            echo "check" > /sys/block/md0/md/sync_action
            echo "'check' has been written to /sys/block/md0/md/sync_action."
            break # Exit the loop
            ;;
        *)
            echo "Invalid selection. Please select 1 or 2."
            # The loop will continue
            ;;
    esac
done
