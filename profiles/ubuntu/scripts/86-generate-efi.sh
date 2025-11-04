#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"

ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/BOOT"
GRUB_CFG="${GRUB_DIR}/grub.cfg"

# Install secure-boot supported packages
apt install -y shim-signed grub-efi-amd64-signed

# Check grub.cfg
[ -f "${GRUB_CFG}" ] || { echo "[$SCRIPT_NAME] ${GRUB_CFG} is missing (run 84 first)"; exit 1; }
# Create EFI directory structure
mkdir -p "${EFI_DIR}"

# Locate shim and grub-signed
SHIM="/usr/lib/shim/shimx64.efi.signed"
GRUB_SIGNED="/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"

# Check existence of signed binaries
if [ ! -f "${SHIM}" ] || [ ! -f "${GRUB_SIGNED}" ]; then
    echo "[$SCRIPT_NAME] ERROR: shim-signed, grub-efi-amd64-signed are not installed"
    exit 1
fi

# Locate shim binary as `BOOTX64.EFI`
cp "${SHIM}" "${EFI_DIR}/BOOTX64.EFI"

# Locate grub-signed binary as `grubx64.efi`
cp "${GRUB_SIGNED}" "${EFI_DIR}/grubx64.efi"

# Copy grub.cfg to the EFI directory (shim requires it)
install -m 0644 -D "${GRUB_CFG}" "${EFI_DIR}/grub.cfg"

echo "[$SCRIPT_NAME] Located shim + grubx64.efi, supports secure boot."

# Create efiboot.img
ESP_IMG="${EFI_DIR}/efiboot.img"
rm -f "${ESP_IMG}"
# Create a blank(zero-filled) 10MB file
dd if=/dev/zero of="${ESP_IMG}" bs=1M count=10
# Create a FAT filesystem on the file
mkfs.vfat -n EFI "${ESP_IMG}"

# Create directory tree and copy files by using mtools
mmd   -i "${ESP_IMG}" ::/EFI ::/EFI/BOOT
mcopy -i "${ESP_IMG}" "${EFI_DIR}/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "${ESP_IMG}" "${EFI_DIR}/grubx64.efi" ::/EFI/BOOT/grubx64.efi
mcopy -i "${ESP_IMG}" "${EFI_DIR}/grub.cfg"   ::/EFI/BOOT/grub.cfg

echo "[$SCRIPT_NAME] Created efiboot.img: ${ESP_IMG}"