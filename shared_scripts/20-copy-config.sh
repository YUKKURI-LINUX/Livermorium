#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Copying scripts into the working directory..."

BASENAME="${BASENAME}"
TARGET_DIR="/mnt/$BASENAME"

# コピー対象（ホスト側: config/config.json）
if [ -f "./config/config.json" ]; then
    mkdir -p "$TARGET_DIR/root/config"
    cp ./config/config.json "$TARGET_DIR/root/config/config.json"
    echo "[$SCRIPT_NAME] Copied config.json."
else
    echo "[$SCRIPT_NAME] Couldn't find config/config.json."
    exit 1
fi

echo "[$SCRIPT_NAME] Copied configs successfully."

