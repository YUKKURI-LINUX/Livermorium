#!/bin/bash
set -e

ISO_PATH="$1"

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "[ERROR] ISOファイルを指定してください"
  echo "使い方: $0 path/to/image.iso"
  exit 1
fi

echo "[INFO] ISOファイル: $ISO_PATH"

# 1. El Torito（BIOS / UEFI ブート）チェック
echo "---------------------------"
echo "[CHECK] El Torito ブート情報"
echo "---------------------------"
xorriso -indev "$ISO_PATH" -report_el_torito plain || echo "[ERROR] El Torito 情報の取得に失敗"

# 2. ファイル構成の確認
echo
echo "---------------------------"
echo "[CHECK] ISOファイル構成"
echo "---------------------------"
TMPDIR=$(mktemp -d)
mountpoint="$TMPDIR/mnt"
mkdir -p "$mountpoint"

echo "[INFO] ISOをマウントして確認: $mountpoint"
sudo mount -o loop "$ISO_PATH" "$mountpoint"

check_file() {
  if [[ -f "$mountpoint/$1" ]]; then
    echo "[OK]   $1"
  else
    echo "[NG]   $1 が存在しません"
  fi
}

check_dir() {
  if [[ -d "$mountpoint/$1" ]]; then
    echo "[OK]   $1/"
  else
    echo "[NG]   $1/ が存在しません"
  fi
}

check_file "boot/grub/i386-pc/eltorito.img"
check_file "boot/grub/grub.cfg"
check_file "EFI/boot/bootx64.efi"
check_file "EFI/boot/grub.cfg"

check_file "casper/vmlinuz"
check_file "casper/initrd"
check_file "casper/filesystem.squashfs"
check_file "casper/filesystem.size"

echo
echo "[INFO] マウント解除します"
sudo umount "$mountpoint"
rm -rf "$TMPDIR"

echo
echo "[DONE] ISOチェック完了"
