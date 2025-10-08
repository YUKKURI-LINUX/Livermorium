#!/bin/bash
set -e
SCRIPT_NAME="$(basename "$0")"
echo "[${SCRIPT_NAME}] Regenerating initrd.img..."

# Get the latest installed kernel version
KERNEL_VERSION=$(ls /lib/modules | sort -V | tail -n 1)
echo "Using kernel version: $KERNEL_VERSION"

# Check if the kernel image exists and reinstall if missing
if [ ! -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
  echo "vmlinuz does not exist. Reinstalling..."
  # Reinstall the kernel image package
  apt install --reinstall "linux-image-$KERNEL_VERSION"
fi


# Set INIT=init in initramfs.conf (replaces existing INIT= or appends)
# Note: The original script's comment says "Set INIT to systemd", but the command writes "INIT=init". 
# The command is kept as "echo 'INIT=init' >> /etc/initramfs-tools/initramfs.conf" to preserve the execution logic.
    echo 'INIT=init' >> /etc/initramfs-tools/initramfs.conf

# /etc/hostname (required for systemd initialization)
echo "livermorium" > /etc/hostname

# Initialize machine-id
systemd-machine-id-setup

# Regenerate initrd.img
update-initramfs -c -k "$KERNEL_VERSION"

# Verify if /init was generated (show as a warning if not)
if lsinitramfs "/boot/initrd.img-$KERNEL_VERSION" | grep -q '^init$'; then
    echo "✓ /init is included"
else
    echo "⚠ /init is NOT included! (Potential cause of kernel panic)"
    exit 1
fi

echo "[${SCRIPT_NAME}] Complete"