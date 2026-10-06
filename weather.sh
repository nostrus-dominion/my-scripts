#!/bin/bash

############
### Version 0.2
### License: Open Source GPL
### Copyright: (c) 2024
############

########################
## ALL THE BORNING STUFF
########################

# Global Variables for ANSI color
source "${XDG_CONFIG_HOME:-$HOME/.config}/my-scripts/colors.conf" || exit 1

# Dependency check
dependencies=("tput" "curl")
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

############
## FUNCTIONS
############

# Function to detect system location based on zip code
detect_location() {
  location=$(curl -s ipinfo.io/postal)
}

# Function to get user input for location
get_user_input() {
  read -rp "Enter the location zip code (or press Enter to use current location): " user_input
  if [ -n "$user_input" ]; then
    location="$user_input"
  fi
}

##################
## START OF SCRIPT
##################

# Splash screen
echo -e "${orange}"
cat << 'SPLASH'
---------------------------------------
|        Weather Check Script        |
---------------------------------------
This script provides weather information
for a specific location.               
---------------------------------------
SPLASH
echo -e "${reset}"

# Get user location
detect_location

# Ask user if they want to use the current location or enter another location
echo "Your approximate location is: $location"
read -rp "Use this location? (Y/n): " choice
if [[ "$choice" != "n" && "$choice" != "N" ]]; then
  # Use current location
  weather_info=$(curl -s https://wttr.in/"$zip_code"?format="%t+%w+%h")
else
  # Get user input for location
  get_user_input
  # Fetch weather information for the user-specified location
  weather_info=$(curl -s https://wttr.in/"$location"?format="%t+%w+%h")
fi

# Display weather information
echo ""
echo "Weather information for $location: "
echo -e " $weather_info "
echo ""
