#!/bin/bash

echo "This doesn't work! Exiting script!"
exit 0

# Define URLs for the latest ISO versions
declare -A urls=(
    ["Archlinux"]="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-$(date +%Y.%m.01)-x86_64.iso"
    #["CentOS"]="https://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-$(curl -s https://www.centos.org/download/ | grep -oP '7-[\d.]+(?=\.iso)').iso"
    ["Clonezilla"]="https://clonezilla.org/downloads/download.php?branch=stable"
    ["Debian"]="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-$(curl -s https://www.debian.org/CD/http-ftp/ | grep -oP 'Debian \K[0-9.]+' | head -1)-amd64-netinst.iso"
    ["Fedora"]="https://download.fedoraproject.org/pub/fedora/linux/releases/$(curl -s https://getfedora.org/ | grep -oP 'Fedora \K\d+' | head -1)/Server/x86_64/iso/Fedora-Server-dvd-x86_64-$(curl -s https://getfedora.org/ | grep -oP 'Fedora \K\d+' | head -1).iso"
    ["FreeBSD"]="https://download.freebsd.org/ftp/releases/ISO-IMAGES/$(curl -s https://www.freebsd.org/where/ | grep -oP '[\d.]+(?=</a></td><td>amd64</td>)' | head -1)/FreeBSD-$(curl -s https://www.freebsd.org/where/ | grep -oP '[\d.]+(?=</a></td><td>amd64</td>)' | head -1)-RELEASE-amd64-dvd1.iso"
    ["Kali"]="https://cdimage.kali.org/kali-$(curl -s https://www.kali.org/get-kali/ | grep -oP '[\d.]+(?=/kali-linux-)' | head -1)/kali-linux-$(curl -s https://www.kali.org/get-kali/ | grep -oP '[\d.]+(?=/kali-linux-)' | head -1)-amd64.iso"
    ["Kubuntu"]="https://cdimage.ubuntu.com/kubuntu/releases/$(curl -s https://cdimage.ubuntu.com/kubuntu/releases/ | grep -oP '[\d.]+(?=/)' | tail -1)/release/kubuntu-$(curl -s https://cdimage.ubuntu.com/kubuntu/releases/ | grep -oP '[\d.]+(?=/)' | tail -1)-desktop-amd64.iso"
    ["MacOS"]="https://support.apple.com/en-us/HT201372"  # Placeholder URL
    ["Manjaro"]="https://download.manjaro.org/xfce/$(curl -s https://manjaro.org/downloads/official/xfce/ | grep -oP 'manjaro-xfce-\K[^"]+.iso' | head -1)"
    ["PopOS"]="https://pop-iso.sfo2.cdn.digitaloceanspaces.com/$(curl -s https://pop.system76.com/ | grep -oP 'pop-os_\K[^"]+.iso' | head -1)"
    ["RHEL"]="https://access.redhat.com/downloads/content/69/ver=/rhel---x86_64"
    ["Raspbian"]="https://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-$(curl -s https://downloads.raspberrypi.org/raspios_armhf/images/ | grep -oP '[\d-]+' | tail -1)/2023-02-21-raspios-bullseye-armhf.img.xz"
    ["Solaris"]="https://www.oracle.com/solaris/solaris11/downloads/solaris-downloads.html"  # Placeholder URL
    ["Ubuntu"]="https://releases.ubuntu.com/$(curl -s https://releases.ubuntu.com/ | grep -oP '[\d.]+(?=/)' | head -1)/ubuntu-$(curl -s https://releases.ubuntu.com/ | grep -oP '[\d.]+(?=/)' | head -1)-desktop-amd64.iso"
    ["Windows"]="https://www.microsoft.com/en-us/software-download/windows10ISO"  # Placeholder URL
    ["openBSD"]="https://cdn.openbsd.org/pub/OpenBSD/$(curl -s https://www.openbsd.org/faq/faq4.html | grep -oP '[\d.]+(?=\s)' | head -1)/amd64/install$(curl -s https://www.openbsd.org/faq/faq4.html | grep -oP '[\d.]+(?=\s)' | head -1).iso"
    ["openSUSE"]="https://download.opensuse.org/distribution/leap/$(curl -s https://get.opensuse.org/leap/ | grep -oP '[\d.]+' | head -1)/iso/openSUSE-Leap-$(curl -s https://get.opensuse.org/leap/ | grep -oP '[\d.]+' | head -1)-DVD-x86_64.iso"
)

# ISO storage directory
mkdir ~/OS-ISO
cd ~/OS-ISO

# Function to download ISO
download_iso() {
    local name=$1
    local url=$2
    echo "Downloading $name..."
    wget -O "${name}.iso" "$url"
}

# Loop through URLs and download the ISOs
for os in "${!urls[@]}"; do
    download_iso "$os" "${urls[$os]}"
done

echo "All downloads completed."
