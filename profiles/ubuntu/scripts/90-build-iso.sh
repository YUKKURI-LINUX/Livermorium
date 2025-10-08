#!/bin/bash
set -e
SCRIPT_NAME="$(basename "$0")"


CHROOT_DIR="${WORK_DIR}/${BASENAME}"
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
CASPER_DIR="${ISO_DIR}/casper"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/BOOT"
I386_DIR="${GRUB_DIR}/i386-pc"
OUT_DIR="${WORK_DIR}/iso_out"

# Create all necessary directories
mkdir -p "${CASPER_DIR}" "${GRUB_DIR}" "${EFI_DIR}" "${I386_DIR}" "${OUT_DIR}"

echo "[$SCRIPT_NAME] Creating filesystem.squashfs..."
# The original commented-out command:
#mksquashfs "${CHROOT_DIR}" "${CASPER_DIR}/filesystem.squashfs" \
#  -e boot proc sys dev tmp run mnt media lost+found var/cache/apt/archives \
#  -no-recovery -noappend

# The current mksquashfs command (with exclusions)
mksquashfs "${CHROOT_DIR}" "${CASPER_DIR}/filesystem.squashfs" \
  -comp xz -b 1M -noappend -no-recovery -wildcards \
  -processors "$(nproc)" \
  -e boot/* \
  -e proc/* -e sys/* \
  -e dev/* \
  -e run/* \
  -e tmp/* \
  -e mnt/* -e media/* \
  -e lost+found \
  -e var/cache/apt/archives/*

# Write the size of the uncompressed filesystem to filesystem.size
du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1 > "${CASPER_DIR}/filesystem.size"

echo "[$SCRIPT_NAME] Copying vmlinuz / initrd..."
# Locate the latest kernel and initrd images
VMLINUZ="$(ls -1 "${CHROOT_DIR}"/boot/vmlinuz-* | sort -V | tail -n1)"
INITRD="$(ls -1 "${CHROOT_DIR}"/boot/initrd.img-* | sort -V | tail -n1)"
# Copy them to the casper directory
cp -f "${VMLINUZ}" "${CASPER_DIR}/vmlinuz"
cp -f "${INITRD}"  "${CASPER_DIR}/initrd"

# Check for required boot files (dependent on previous steps 84, 85, 86)
[ -f "${GRUB_DIR}/grub.cfg" ] || { echo "[$SCRIPT_NAME] grub.cfg is missing (84 not executed)"; exit 1; }
[ -f "${I386_DIR}/eltorito.img" ] || { echo "[$SCRIPT_NAME] eltorito.img is missing (85 not executed)"; exit 1; }
[ -f "${EFI_DIR}/BOOTX64.EFI" ] || { echo "[$SCRIPT_NAME] BOOTX64.EFI is missing (86 not executed)"; exit 1; }

echo "[$SCRIPT_NAME] Generating md5sum.txt..."
(
  cd "${ISO_DIR}"
  # Find all files except md5sum.txt and calculate their checksums
  find . -type f ! -name "md5sum.txt" -exec md5sum {} + > md5sum.txt
)

OUT_ISO="${OUT_DIR}/${BASENAME}-$(date +%Y%m%d_%H%M).iso"
echo "[$SCRIPT_NAME] Creating ISO with xorriso... -> ${OUT_ISO}"

xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "${BASENAME}" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-catalog boot/grub/boot.cat \
  -eltorito-alt-boot \
    -e EFI/BOOT/efiboot.img \
    -no-emul-boot \
  -isohybrid-gpt-basdat \
  -output "${OUT_ISO}" \
  "${ISO_DIR}"

echo "[$SCRIPT_NAME] Complete: ${OUT_ISO}"