#!/bin/bash

############
### Version 0.5
### License: Open Source GPL
### Copyright: (c) 2024
############
### BASED ON THE FOLLOWING SCRIPT:
### James Morris
### https://github.com/JRMorris77/system_maintenance/blob/main/system_maintenance.sh
############

### CHECKS AND CONSTANTS

# Color variables
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
orange=$(tput setaf 166)
cyan=$(tput setaf 6)
reset=$(tput sgr0) # No Color

# Check if user has root privileges
if [ "$EUID" -ne 0 ]; then
    echo
    echo -e  ${red}"    Please run as root!!!  "${reset}
    echo
    exit 1
fi

# Log file
log_file="/var/log/system_maintenance.log"
log() {
    local message="$1"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") : $message" | tee -a $log_file
}
exec > >(tee -a "$log_file") 2>&1 # Redirect stdout and stderr to the log file

############
### THIS IS WHERE THE FUN BEGINS
############

### DETECT AND DISPLAY SYSTEM INFORMATION
echo ""
echo "System Information"
echo "========================================"
# get processor information
processor_name=$(grep "model name" /proc/cpuinfo | cut -d ' ' -f3- | awk {'print $0'} | head -1)
processor_count=$(grep -ioP 'processor\t:' /proc/cpuinfo | wc -l)

# Function to detect GPU
detect_gpu() {
    if command -v nvidia-smi &>/dev/null; then
        system_gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        model_number=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | head -n 1)
    elif lspci | grep -i AMD &>/dev/null; then
        system_gpu=$(lspci | grep -i AMD | grep -oP "(?<=\[).+?(?=\])" | head -n 1)
        model_number=$(lspci | grep -i AMD | grep -i VGA | cut -d ' ' -f12- | head -1)
    else
        manufacturer="Unknown"
        system_gpu="${yellow}No compatible GPU found${reset}"
        model_number="N/A"
    fi
}
detect_gpu

# Get process information
process=$(ps -eo user=|sort|uniq -c | awk '{ print $2 " " $1 }')
process_all=$(echo "$process" | awk {'print $2'} | awk '{ SUM += $1} END { print SUM }')
process_root=$(echo "$process" | grep root | awk {'print $2'})
process_user=$(echo "$process" | grep -v root | awk {'print $2'} | awk '{ SUM += $1} END { print SUM }')

# get load averages
IFS=" " read load1 load5 load15 <<<$(cat /proc/loadavg | awk '{ print $1,$2,$3 }')

# get free memory
IFS=" " read used avail total <<<$(free -htm | grep "Mem" | awk {'print $3,$7,$2'})

# get swap usage
IFS=" " read swap_used swap_total <<<$(free -htm | grep "Swap" | awk {'print $3,$2'})

echo -e "${reset}  Hostname....: ${green}$(hostname)
${reset}  Distro......: ${reset}$(cat /etc/*release | grep "PRETTY_NAME" | cut -d "=" -f 2- | sed 's/"//g')
${reset}  Kernel......: ${reset}$(uname -sr)
${reset}  Uptime......: ${reset}$(uptime -p)
${reset}  CPU.........: ${reset}$processor_name (${green}$processor_count${reset} vCPU)
${reset}  GPU.........: ${reset}$system_gpu $model_number
${reset}  Processes...: ${reset}${green}$process_root${reset} (root), ${green}$process_user${reset} (user), ${green}$process_all${reset} (total)
${reset}  Load........: ${green}$load1${reset} (1m), ${green}$load5${reset} (5m), ${green}$load15${reset} (15m)
${reset}  RAM.USAGE...: ${green}$used${reset} used, ${green}$avail${reset} avail, ${green}$total${reset}
${reset}  SWAP.USAGE..: ${green}$swap_used${reset} used, ${green}$swap_total${reset} total"

### CHECKING UPDATES FROM PACAKGE MANAGERS
echo ""
echo "Checking for package managers..."
echo "========================================"
declare -A osInfo;
osInfo[/etc/redhat-release]=yum
osInfo[/etc/arch-release]=pacman
osInfo[/etc/gentoo-release]=emerge
osInfo[/etc/SuSE-release]=zypp
osInfo[/etc/debian_version]=apt
osInfo[/etc/alpine-release]=apk
osInfo[/usr/bin/snap]=snap

# Collect detected package managers
detected_pkg_managers=()

for f in "${!osInfo[@]}"
do
    if [[ -f $f ]]; then
        detected_pkg_managers+=("${osInfo[$f]}")
    fi
done

# Sort and print detected package managers
IFS=$'\n' sorted_pkg_managers=($(sort <<<"${detected_pkg_managers[*]}"))
unset IFS

for pkg_manager in "${sorted_pkg_managers[@]}"
do
    echo "Package manager: ${green}${pkg_manager}"${reset}
done

# Function to check for updates for each package manager
check_updates() {
    case $1 in
        apt)
            sudo apt update && sudo apt list --upgradable
            echo
            ;;
        yum)
            sudo yum check-update | awk 'p; /Updated packages/ {p=1}'
            echo
            ;;
        pacman)
            sudo pacman checkupdates
            echo
            ;;
        emerge)
            sudo emerge --sync
            echo
            ;;
        zypp)
            sudo zypper refresh
            echo
            ;;
        apk)
            sudo apk -u list
            echo
            ;;
        snap)
            sudo snap refresh --list
            ;;
    esac
}

# Function to install updates for each package manager
install_updates() {
    case $1 in
        apt)
            sudo apt upgrade -y
            ;;
        yum)
            sudo yum update -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        emerge)
            sudo emerge --update --deep --with-bdeps=y @world
            ;;
        zypp)
            sudo zypper update -y
            ;;
        apk)
            sudo apk upgrade
            ;;
        snap)
            sudo snap refresh
            ;;
    esac
}

# Prompt user to check for updates
echo ""
read -p "Would you like to check for updates for the detected package managers? (y/n): " check_updates_response
echo ""

if [[ $check_updates_response == [yY] || $check_updates_response == [yY][eE][sS] ]]; then
    for pkg_manager in "${sorted_pkg_managers[@]}"
    do
        echo "Checking for updates using ${green}${pkg_manager}${reset}..."
        echo ""
        check_updates $pkg_manager
    done
    echo ""
    echo "Checking for updates have been completed."

    # Prompt user to install updates
    echo ""
    read -p "Would you like to install the updates? (y/n): " install_updates_response
    echo ""

    if [[ $install_updates_response == [yY] || $install_updates_response == [yY][eE][sS] ]]; then
        for pkg_manager in "${sorted_pkg_managers[@]}"
        do
            echo ""
            echo "Installing updates using ${green}${pkg_manager}${reset}..."
            install_updates $pkg_manager
        done
        echo "========================================"
        echo -e "${red}Updates have been installed!${reset}"
        echo ""
    else
        echo "========================================"
        echo -e "${red}Skipping update installation.${reset}"
        echo ""
    fi
else
    echo "========================================"
    echo "${red}Skipping update check and installation.${reset}"
    echo ""
fi

### CLEAR PACKAGE MANAGER CACHE
echo ""
echo "Clearing package manager data..."
echo "========================================"
# Function to clean and clear package manager cache and remove unused packages
clean_cache_and_remove_unused() {
    case $1 in
        apt)
            sudo apt autoremove -y
            sudo apt clean
            ;;
        yum)
            sudo yum autoremove -y
            sudo yum clean all
            ;;
        pacman)
            sudo pacman -Rns $(pacman -Qtdq) --noconfirm
            sudo pacman -Sc --noconfirm
            ;;
        emerge)
            sudo emerge --depclean
            sudo eclean-dist
            sudo eclean-pkg
            ;;
        zypp)
            sudo zypper remove -u
            sudo zypper clean --all
            ;;
        apk)
            sudo apk autoremove
            sudo apk cache clean
            ;;
        snap)
            sudo sh -c 'rm -rf /var/lib/snapd/cache/*'
            ;;
    esac
}

for pkg_manager in "${sorted_pkg_managers[@]}"
do
    echo ""
    echo "Cleaning cache and removing unused packages using ${green}${pkg_manager}${reset}..."
    echo ""
    clean_cache_and_remove_unused $pkg_manager
done
echo "========================================"
echo -e "${red}Package manager data cleared!${reset}"

### CLEARING DNS RESOLVER
echo ""
echo "Display Resolver Statistics"
echo "========================================"
# Show DNS Cache pre-flush
sudo resolvectl statistics

# Prompt user to clear DNS cache
echo ""
read -p "Would you like to clear the DNS cache? (y/n): " clear_dns_response
echo ""

if [[ $clear_dns_response == [yY] || $clear_dns_response == [yY][eE][sS] ]]; then
    echo "Clearing DNS Cache..."
    echo "========================================"
    echo "..."
    # Clear DNS cache using resolvectl
    sudo resolvectl flush-caches
    echo "========================================"
    echo -e "${red}DNS cache cleared!${reset}"
    echo ""
else
    echo "========================================"
    echo -e "${red}Skipping DNS cache clearing.${reset}"
    echo ""
fi

### RESET SWAP AREA IF THERE IS ONE
echo "Checking for active swap space..."
echo "========================================"

# Check if there is any active swap space
if sudo swapon --show | grep -q '^'; then
    echo "Active swap space detected."
    echo "Clearing Swap Space..."
    echo "========================================"
    echo "..."
    sudo swapoff -a && sudo swapon -a
    echo "========================================"
    echo -e "${red}Swap Space cleared!${reset}"
else
    echo "No active swap space detected."
fi
echo ""

### CLEAR INODES AND DENTRIES
echo "Clear Page Cache, Dentries, & Inodes..."
echo "========================================"
# Free up page cache, dentries, and inodes
sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
echo "========================================"
echo -e "${red}Page Cache, Dentries, & Inodes Cleared!${reset}"
echo ""

### SYSTEM REBOOT PROMPT
echo ""
echo "System reboot"
echo "========================================"
# Prompt user to reboot the system
echo ""
read -p "Would you like to reboot the system? (y/n): " reboot_response
echo ""

if [[ $reboot_response == [yY] || $reboot_response == [yY][eE][sS] ]]; then
    echo "========================================"
    echo -e "${red}Rebooting the system...${reset}"
    sleep 2
    sudo reboot
else
    # All Finished!
    echo -e "========================================"
    echo -e "${red}All Maintenance Tasks Complete! Goodbye!"${reset}
    echo -e "========================================"
fi
