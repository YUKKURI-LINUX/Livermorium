#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting host-side initialization..."

echo "[$SCRIPT_NAME]: Checking the installation of required tools..."

# NOTE: This script is deeply depending on the Ubuntu system. If you're about to create a new preset not on the Ubuntu basement, this script won't work.

# Update the package list
apt update
# Install required tools
apt install -y debootstrap xorriso grub-pc-bin xorriso mtools squashfs-tools

echo "[$SCRIPT_NAME]: All tools are updated successfully."

# Check BASENAME
BASENAME="${BASENAME}"
TARGET_DIR="$WORK_DIR/$BASENAME"

ISO_DIR="$WORK_DIR/iso/${BASENAME}"

# Delete the previous working directory
if [ -d "$TARGET_DIR" ]; then
    echo "[$SCRIPT_NAME] Deleting the previous version of $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
fi

if [ -d "$ISO_DIR" ]; then
    echo "[$SCRIPT_NAME] Deleting the previous version of $ISO_DIR..."
    rm -rf "$ISO_DIR"
fi
# Create a new working directory
mkdir -p "$TARGET_DIR"

echo "[$SCRIPT_NAME] Process finished successfully. The working directory is : $TARGET_DIR"