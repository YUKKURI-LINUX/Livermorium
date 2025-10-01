#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"

ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/BOOT"      # 大文字 BOOT に統一
GRUB_CFG="${GRUB_DIR}/grub.cfg"

[ -f "${GRUB_CFG}" ] || { echo "[$SCRIPT_NAME] ${GRUB_CFG} がありません（84を先に実行）"; exit 1; }
mkdir -p "${EFI_DIR}"

# 1) GRUB スタンドアロン EFI を生成（必要モジュールを明示）
REQUIRED_MODS="part_gpt part_msdos iso9660 fat normal linux search search_label search_fs_file search_fs_uuid configfile"
rm -f "${EFI_DIR}/BOOTX64.EFI"
grub-mkstandalone \
  -O x86_64-efi \
  -o "${EFI_DIR}/BOOTX64.EFI" \
  --disable-shim-lock \
  --modules="${REQUIRED_MODS}" \
  "boot/grub/grub.cfg=${GRUB_CFG}"

# 2) FAT の ESP イメージ（efiboot.img）を作成し、BOOTX64.EFI を内包
ESP_IMG="${EFI_DIR}/efiboot.img"
rm -f "${ESP_IMG}"
dd if=/dev/zero of="${ESP_IMG}" bs=1M count=8
mkfs.vfat -n EFI "${ESP_IMG}"

# mtools でディレクトリ作成＆コピー
mmd   -i "${ESP_IMG}" ::/EFI ::/EFI/BOOT
mcopy -i "${ESP_IMG}" "${EFI_DIR}/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI

echo "[$SCRIPT_NAME] 作成: ${EFI_DIR}/BOOTX64.EFI と ${ESP_IMG}"
