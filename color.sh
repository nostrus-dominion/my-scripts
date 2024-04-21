# Color variables
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
reset=$(tput sgr0) # No Color


# Usage example
echo -e "${green}This text is green.${reset}"
echo -e "${yellow}This text is yellow.${reset}"
echo -e "${red}This text is red.${reset}"
echo -e "${blue}This text is blue.${reset}"
echo -e "${purple}This text is purple.${reset}"
echo -e "${orange}This text is orange.${reset}"
echo -e "${cyan}This text is cyan.${reset}"
echo -e "${reset}This text is normal.${reset}"

