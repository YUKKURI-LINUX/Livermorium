#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] chroot 環境のアンマウントとクリーンアップを開始..."

BASENAME="${BASENAME:=hogehoge-ubuntu}"
CHROOT_DIR="../work_build/$BASENAME"

# アンマウント対象
MOUNT_POINTS=(
  "$CHROOT_DIR/dev/pts"
  "$CHROOT_DIR/dev"
  "$CHROOT_DIR/sys"
  "$CHROOT_DIR/proc"
)

# アンマウント処理（順番に注意）
for mp in "${MOUNT_POINTS[@]}"; do
  if mountpoint -q "$mp"; then
    umount "$mp"
    echo "[$SCRIPT_NAME] アンマウント: $mp"
  else
    echo "[$SCRIPT_NAME] スキップ: $mp はマウントされていません"
  fi
done

echo "[$SCRIPT_NAME] chroot 環境のクリーンアップ完了"

