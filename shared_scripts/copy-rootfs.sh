#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Copying rootfs..."

TARGET_DIR="${WORK_DIR}/$BASENAME"

# Check the parent script's name to determine the subdirectory
if [[ "$SCRIPT_NAME" == *before* ]]; then
    ROOTFS_SUBDIR="rootfs_before"
elif [[ "$SCRIPT_NAME" == *after* ]]; then
    ROOTFS_SUBDIR="rootfs_after"
else
    echo "[$SCRIPT_NAME] The parent script's name does not contain 'before' or 'after'"
    exit 1
fi

ROOTFS_SOURCE="$PROFILE_DIR/$ROOTFS_SUBDIR"

# Check if the source directory exists
if [ ! -d "$ROOTFS_SOURCE" ]; then
    echo "[$SCRIPT_NAME] $ROOTFS_SOURCE does not exist. Skipping."
    exit 0
fi

echo "[$SCRIPT_NAME] Source: $ROOTFS_SOURCE"
echo "[$SCRIPT_NAME] Destination: $TARGET_DIR"

# Copy contents of the source directory to the target directory
cp -a "$ROOTFS_SOURCE/." "$TARGET_DIR/"

echo "[$SCRIPT_NAME] $ROOTFS_SUBDIR is copied successfully."