#!/bin/bash
set -e

ISO_PATH="$1"

# Check if an ISO file path is provided and if the file exists
if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "[ERROR] Please specify the ISO file path"
  echo "Usage: $0 path/to/image.iso"
  exit 1
fi

echo "[INFO] ISO File: $ISO_PATH"

# 1. El Torito (BIOS / UEFI Boot) Check
echo "---------------------------"
echo "[CHECK] El Torito Boot Information"
echo "---------------------------"
# Report El Torito boot info; output an error message on failure
xorriso -indev "$ISO_PATH" -report_el_torito plain || echo "[ERROR] Failed to retrieve El Torito information"

# 2. File Structure Check
echo
echo "---------------------------"
echo "[CHECK] ISO File Structure"
echo "---------------------------"
TMPDIR=$(mktemp -d)
mountpoint="$TMPDIR/mnt"
mkdir -p "$mountpoint"

echo "[INFO] Mounting ISO for verification: $mountpoint"
# Mount the ISO using the loop device
sudo mount -o loop "$ISO_PATH" "$mountpoint"

# Function to check for file existence
check_file() {
  if [[ -f "$mountpoint/$1" ]]; then
    echo "[OK]   $1"
  else
    echo "[NG]   $1 does not exist"
  fi
}

# Function to check for directory existence (currently unused in original script, but kept for completeness if needed)
check_dir() {
  if [[ -d "$mountpoint/$1" ]]; then
    echo "[OK]   $1/"
  else
    echo "[NG]   $1/ does not exist"
  fi
}

# Check for essential boot and filesystem files
check_file "boot/grub/i386-pc/eltorito.img"
check_file "boot/grub/grub.cfg"
check_file "EFI/boot/bootx64.efi"
check_file "EFI/boot/grub.cfg"

check_file "casper/vmlinuz"
check_file "casper/initrd"
check_file "casper/filesystem.squashfs"
check_file "casper/filesystem.size"

echo
echo "[INFO] Unmounting ISO"
# Unmount the ISO and remove the temporary directory
sudo umount "$mountpoint"
rm -rf "$TMPDIR"

echo
echo "[DONE] ISO check complete"