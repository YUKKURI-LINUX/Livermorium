#!/bin/bash
set -e
SCRIPT_NAME="$(basename "$0")"


WORK_DIR="../work_build"
CHROOT_DIR="${WORK_DIR}/${BASENAME}"
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
CASPER_DIR="${ISO_DIR}/casper"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/boot"
I386_DIR="${GRUB_DIR}/i386-pc"
OUT_DIR="${WORK_DIR}/iso_out"

mkdir -p "${CASPER_DIR}" "${GRUB_DIR}" "${EFI_DIR}" "${I386_DIR}" "${OUT_DIR}"

echo "[$SCRIPT_NAME] filesystem.squashfs を作成中..."
#mksquashfs "${CHROOT_DIR}" "${CASPER_DIR}/filesystem.squashfs" \
#  -e boot proc sys dev tmp run mnt media lost+found var/cache/apt/archives \
#  -no-recovery -noappend

mksquashfs "${CHROOT_DIR}" "${CASPER_DIR}/filesystem.squashfs" \
  -comp xz -b 1M -noappend -no-recovery -wildcards \
  -e boot/* \
  -e proc/* -e sys/* \
  -e dev/* \
  -e run/* \
  -e tmp/* \
  -e mnt/* -e media/* \
  -e lost+found \
  -e var/cache/apt/archives/*

du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1 > "${CASPER_DIR}/filesystem.size"

echo "[$SCRIPT_NAME] vmlinuz / initrd をコピー中..."
VMLINUZ="$(ls -1 "${CHROOT_DIR}"/boot/vmlinuz-* | sort -V | tail -n1)"
INITRD="$(ls -1 "${CHROOT_DIR}"/boot/initrd.img-* | sort -V | tail -n1)"
cp -f "${VMLINUZ}" "${CASPER_DIR}/vmlinuz"
cp -f "${INITRD}"  "${CASPER_DIR}/initrd"

[ -f "${GRUB_DIR}/grub.cfg" ] || { echo "[$SCRIPT_NAME] grub.cfg がありません（84未実行）"; exit 1; }
[ -f "${I386_DIR}/eltorito.img" ] || { echo "[$SCRIPT_NAME] eltorito.img がありません（85未実行）"; exit 1; }
[ -f "${EFI_DIR}/bootx64.efi" ] || { echo "[$SCRIPT_NAME] bootx64.efi がありません（86未実行）"; exit 1; }

echo "[$SCRIPT_NAME] md5sum.txt を生成中..."
(
  cd "${ISO_DIR}"
  find . -type f ! -name "md5sum.txt" -exec md5sum {} + > md5sum.txt
)

OUT_ISO="${OUT_DIR}/${BASENAME}-$(date +%Y%m%d_%H%M).iso"
echo "[$SCRIPT_NAME] xorriso で ISO を作成中... -> ${OUT_ISO}"

xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "${BASENAME}" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-catalog boot/grub/boot.cat \
  -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi \
    -no-emul-boot \
  -isohybrid-gpt-basdat \
  -output "${OUT_ISO}" \
  "${ISO_DIR}"

echo "[$SCRIPT_NAME] 完了: ${OUT_ISO}"
