#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] rootfs のコピー処理を開始..."

TARGET_DIR="../work_build/$BASENAME"

if [[ "$SCRIPT_NAME" == *before* ]]; then
    ROOTFS_SUBDIR="rootfs_before"
elif [[ "$SCRIPT_NAME" == *after* ]]; then
    ROOTFS_SUBDIR="rootfs_after"
else
    echo "[$SCRIPT_NAME] スクリプト名に 'before' または 'after' が含まれていません"
    exit 1
fi

ROOTFS_SOURCE="./profiles/$PROFILENAME/$ROOTFS_SUBDIR"

if [ ! -d "$ROOTFS_SOURCE" ]; then
    echo "[$SCRIPT_NAME] $ROOTFS_SOURCE が存在しません。スキップします。"
    exit 0
fi

echo "[$SCRIPT_NAME] コピー元: $ROOTFS_SOURCE"
echo "[$SCRIPT_NAME] コピー先: $TARGET_DIR"

cp -a "$ROOTFS_SOURCE/." "$TARGET_DIR/"

echo "[$SCRIPT_NAME] $ROOTFS_SUBDIR のコピー完了"

