#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] ホスト側の初期準備を開始..."

echo "[$SCRIPT_NAME]: Checking the installation of required tools..."

apt update
apt install -y debootstrap xorriso grub-pc-bin xorriso mtools squashfs-tools

echo "[$SCRIPT_NAME]: Process finished successfully."

# BASENAMEの確認
BASENAME="${BASENAME}"
TARGET_DIR="../work_build/$BASENAME"

ISO_DIR="../work_build/iso/${BASENAME}"

# 既存ディレクトリがあれば削除
if [ -d "$TARGET_DIR" ]; then
    echo "[$SCRIPT_NAME] 既存の $TARGET_DIR を削除します..."
    rm -rf "$TARGET_DIR"
fi

if [ -d "$ISO_DIR" ]; then
    echo "[$SCRIPT_NAME] 既存の $ISO_DIR を削除します..."
    rm -rf "$ISO_DIR"
fi
# ベースディレクトリ作成
mkdir -p "$TARGET_DIR"

echo "[$SCRIPT_NAME] ホスト初期準備完了: $TARGET_DIR"

