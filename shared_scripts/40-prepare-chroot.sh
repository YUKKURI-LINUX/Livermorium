#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting chroot environment preparation (mounting, etc.)..."

BASENAME="${BASENAME}"
CHROOT_DIR="${WORK_DIR}/$BASENAME"

# bind mounts
for fs in proc sys dev dev/pts; do
    if [ ! -d "$CHROOT_DIR/$fs" ]; then
        mkdir -p "$CHROOT_DIR/$fs"
    fi
    # Perform a bind mount
    mount --bind "/$fs" "$CHROOT_DIR/$fs"
done

echo "[$SCRIPT_NAME] chroot environment mounting complete"