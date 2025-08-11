#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME]: Checking the installation of required tools..."

apt update
apt install -y debootstrap xorriso grub-efi-amd64-bin

echo "[$SCRIPT_NAME]: Process finished successfully."