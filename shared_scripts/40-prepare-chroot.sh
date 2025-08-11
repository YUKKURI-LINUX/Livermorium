#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] chroot 環境の準備（マウント等）を開始..."

BASENAME="${BASENAME}"
CHROOT_DIR="../work_build/$BASENAME"

# bindマウント
for fs in proc sys dev dev/pts; do
    if [ ! -d "$CHROOT_DIR/$fs" ]; then
        mkdir -p "$CHROOT_DIR/$fs"
    fi
    mount --bind "/$fs" "$CHROOT_DIR/$fs"
done

echo "[$SCRIPT_NAME] chroot 環境のマウント完了"

