#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting chroot environment unmount and cleanup..."

# Set BASENAME with a default value
BASENAME="${BASENAME:=hogehoge-ubuntu}"
CHROOT_DIR="$WORK_DIR/$BASENAME"

# Mount points to unmount
MOUNT_POINTS=(
  "$CHROOT_DIR/dev/pts"
  "$CHROOT_DIR/dev"
  "$CHROOT_DIR/sys"
  "$CHROOT_DIR/proc"
)

# Unmount process (order is important)
for mp in "${MOUNT_POINTS[@]}"; do
  # Check if the path is actually a mount point
  if mountpoint -q "$mp"; then
    umount "$mp"
    echo "[$SCRIPT_NAME] Unmounted: $mp"
  else
    echo "[$SCRIPT_NAME] Skipped: $mp is not mounted"
  fi
done

echo "[$SCRIPT_NAME] chroot environment cleanup complete"