#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] /home/$USERNAME の所有権変更を開始..."

TARGET_DIR="../work_build/$BASENAME"

if [ -z "$USERNAME" ]; then
    echo "[$SCRIPT_NAME] USERNAME が未定義です"
    exit 1
fi

chroot "$TARGET_DIR" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

echo "[$SCRIPT_NAME] 所有権変更完了"

