#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"


WORK_DIR="../work_build"
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/boot"
GRUB_CFG="${GRUB_DIR}/grub.cfg"

[ -f "${GRUB_CFG}" ] || { echo "[86] ${GRUB_CFG} がありません（84を先に実行）"; exit 1; }
mkdir -p "${EFI_DIR}"

grub-mkstandalone \
  -O x86_64-efi \
  -o "${EFI_DIR}/bootx64.efi" \
  "boot/grub/grub.cfg=${GRUB_CFG}"

echo "[$SCRIPT_NAME] UEFI用 bootx64.efi 作成: ${EFI_DIR}/bootx64.efi"
