#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"

ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/BOOT"
GRUB_CFG="${GRUB_DIR}/grub.cfg"

apt install -y shim-signed grub-efi-amd64-signed

[ -f "${GRUB_CFG}" ] || { echo "[$SCRIPT_NAME] ${GRUB_CFG} がありません（84を先に実行）"; exit 1; }
mkdir -p "${EFI_DIR}"

# --- 1) shim + signed grub を配置 ---
SHIM="/usr/lib/shim/shimx64.efi.signed"
GRUB_SIGNED="/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"

if [ ! -f "${SHIM}" ] || [ ! -f "${GRUB_SIGNED}" ]; then
    echo "[$SCRIPT_NAME] ERROR: shim-signed, grub-efi-amd64-signed がインストールされていません"
    exit 1
fi

# BOOTX64.EFI = shim
cp "${SHIM}" "${EFI_DIR}/BOOTX64.EFI"

# grubx64.efi = 署名済み grub
cp "${GRUB_SIGNED}" "${EFI_DIR}/grubx64.efi"

# grub.cfg を EFI 配下にもコピー（shim が探す場合に備え）
install -m 0644 -D "${GRUB_CFG}" "${EFI_DIR}/grub.cfg"

echo "[$SCRIPT_NAME] Secure Boot 対応 shim + grubx64.efi を配置しました"

# --- 2) efiboot.img を作成し、上記を内包 ---
ESP_IMG="${EFI_DIR}/efiboot.img"
rm -f "${ESP_IMG}"
dd if=/dev/zero of="${ESP_IMG}" bs=1M count=10
mkfs.vfat -n EFI "${ESP_IMG}"

# mtoolsでツリーを作成してコピー
mmd   -i "${ESP_IMG}" ::/EFI ::/EFI/BOOT
mcopy -i "${ESP_IMG}" "${EFI_DIR}/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "${ESP_IMG}" "${EFI_DIR}/grubx64.efi" ::/EFI/BOOT/grubx64.efi
mcopy -i "${ESP_IMG}" "${EFI_DIR}/grub.cfg"   ::/EFI/BOOT/grub.cfg

echo "[$SCRIPT_NAME] efiboot.img を作成しました: ${ESP_IMG}"
