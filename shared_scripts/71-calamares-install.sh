#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Installing Calamares..."

# Check /etc/os-release for getting distribution ID
if [ -f /etc/os-release ]; then
    source /etc/os-release
fi

# Install Calamares based on the distribution ID
if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
    pacman -Sy --noconfirm calamares
elif [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* ]]; then
    apt update
    apt install -y calamares
elif [[ "$ID" == "fedora" || "$ID_LIKE" == *"fedora"* ]]; then
    dnf install -y calamares
elif [[ "$ID" == "opensuse-tumbleweed" || "$ID_LIKE" == *"suse"* ]]; then
    zypper install -y calamares
else
    echo "[$SCRIPT_NAME] This distribution is not supported."
    exit 1
fi

echo "[$SCRIPT_NAME] Installed Calamares successfully"