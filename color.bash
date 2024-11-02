#!/bin/bash

## Version 0.1
## License: Open Source GPL
## Copyright: (c) 2023

# Color variables
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
blue='\033[0;34m'
purple='\033[0;35m'
orange='\033[0;38;5;166m'
cyan='\033[0;36m'
dim='\033[2m'
reset='\033[0m' # No Color

echo -e "${green}This is green text${reset}"
echo -e "${yellow}This is yellow text${reset}"
echo -e "${red}This is red text${reset}"
echo -e "${blue}This is blue text${reset}"
echo -e "${purple}This is purple text${reset}"
echo -e "${orange}This is orange text${reset}"
echo -e "${cyan}This is cyan text${reset}"
echo -e "${dim}This is dim text${reset}"
echo -e "${reset}This text is normal.${reset}"
