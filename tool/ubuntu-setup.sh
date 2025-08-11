#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Livermorium ツールの環境構築を開始します..."

# 必要なパッケージをインストール
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-pip python3-gi \
  gir1.2-gtk-4.0 gir1.2-gtksource-4 \
  grub-pc-bin xorriso mtools squashfs-tools \
  debootstrap qemu-user-static



# PyGObject をインストール
pip install --upgrade pip
pip install PyGObject

echo "[$SCRIPT_NAME] 環境構築完了。次のコマンドで起動できます:"
echo ""
echo "  python3 gui/main.py"
