#!/bin/bash

# Version 0.2

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

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
