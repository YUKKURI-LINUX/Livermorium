#!/bin/bash
set -e

SCRIPT_NAME=$(basename "$0")
echo "[$SCRIPT_NAME] Enabling required systemd services..."

#ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# Automatic enabling of the display manager
#ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

#if command -v lightdm &>/dev/null; then
#    echo "[$SCRIPT_NAME] Enabling lightdm"
#    systemctl enable lightdm
#elif command -v gdm3 &>/dev/null; then
#    echo "[$SCRIPT_NAME] Enabling gdm3"
#    systemctl enable gdm3
#elif command -v gdm &>/dev/null; then
#    echo "[$SCRIPT_NAME] Enabling gdm"
#    systemctl enable gdm
#elif command -v sddm &>/dev/null; then
#    echo "[$SCRIPT_NAME] Enabling sddm"
#    systemctl enable sddm
#else
#    echo "[$SCRIPT_NAME] Display manager not found"
#fi

# Network Manager services
#if systemctl list-unit-files | grep -q NetworkManager.service; then
#    echo "[$SCRIPT_NAME] Enabling NetworkManager..."
#    systemctl enable NetworkManager
#elif systemctl list-unit-files | grep -q wicked.service; then
#    echo "[$SCRIPT_NAME] Enabling wicked..."
#    systemctl enable wicked
#elif systemctl list-unit-files | grep -q systemd-networkd.service; then
#    echo "[$SCRIPT_NAME] Enabling systemd-networkd..."
#    systemctl enable systemd-networkd
#else
#    echo "[$SCRIPT_NAME] No supported network manager service is installed."
#fi

# Bluetooth service
if systemctl list-unit-files | grep -q bluetooth.service; then
    echo "[$SCRIPT_NAME] Enabling bluetooth..."
    systemctl enable bluetooth
fi

# Printer service (cups)
if systemctl list-unit-files | grep -q cups.service; then
    echo "[$SCRIPT_NAME] Enabling cups"
    systemctl enable cups
fi

echo "[$SCRIPT_NAME] All required services are successfully enabled."
