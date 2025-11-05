#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Changing the ownership of /home/$USERNAME..."

TARGET_DIR="${WORK_DIR}/$BASENAME"

# Verify USERNAME defined
if [ -z "$USERNAME" ]; then
    echo "[$SCRIPT_NAME] USERNAME is undefined"
    exit 1
fi

# Change ownership of the user's home directory inside the chroot environment
chroot "$TARGET_DIR" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

echo "[$SCRIPT_NAME] Changed ownerships successfully"