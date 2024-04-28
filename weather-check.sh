#!/bin/bash

# Global color variables
red=$(tput setaf 1)
orange=$(tput setaf 166)
reset=$(tput sgr0) # No Color

# Checking if dependancies are installed
deps=("jq" "curl")

for dep in "${deps[@]}"; do
if ! which "$dep" > /dev/null; then
    echo -e "${red}CRITCAL ERROR!! $dep is not installed or not in the PATH${reset}"
    exit 1
fi
done

# Splash screen
echo -e "${orange}"
echo -e "---------------------------------------"
echo -e "|        Weather Check Script        |"
echo -e "---------------------------------------"
echo -e "This script provides weather information"
echo -e "for a specific location.               "
echo -e "---------------------------------------"
echo -e "${reset}"

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
