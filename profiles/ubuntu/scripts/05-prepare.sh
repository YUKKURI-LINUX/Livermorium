#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting host-side initial preparation..."

echo "[$SCRIPT_NAME]: Checking the installation of required tools..."

# Update package lists
apt update
# Install required tools
apt install -y debootstrap xorriso grub-pc-bin xorriso mtools squashfs-tools

echo "[$SCRIPT_NAME]: Process finished successfully."

# Check BASENAME
BASENAME="${BASENAME}"
TARGET_DIR="$WORK_DIR/$BASENAME"

ISO_DIR="$WORK_DIR/iso/${BASENAME}"

# Remove existing directories if they exist
if [ -d "$TARGET_DIR" ]; then
    echo "[$SCRIPT_NAME] Deleting existing $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
fi

if [ -d "$ISO_DIR" ]; then
    echo "[$SCRIPT_NAME] Deleting existing $ISO_DIR..."
    rm -rf "$ISO_DIR"
fi
# Create the base directory
mkdir -p "$TARGET_DIR"

echo "[$SCRIPT_NAME] Host initial preparation complete: $TARGET_DIR"