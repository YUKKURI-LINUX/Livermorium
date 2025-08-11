#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] 設定ファイルの chroot 環境へのコピーを開始..."

BASENAME="${BASENAME}"
TARGET_DIR="/mnt/$BASENAME"

# コピー対象（ホスト側: config/config.json）
if [ -f "./config/config.json" ]; then
    mkdir -p "$TARGET_DIR/root/config"
    cp ./config/config.json "$TARGET_DIR/root/config/config.json"
    echo "[$SCRIPT_NAME] config.json をコピーしました"
else
    echo "[$SCRIPT_NAME] config/config.json が見つかりません"
    exit 1
fi

echo "[$SCRIPT_NAME] 設定ファイルコピー完了"

