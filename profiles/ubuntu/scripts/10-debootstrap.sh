#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Ubuntu ベースシステム構築を開始..."

# 環境変数の取得（デフォルト指定あり）
BASENAME="${BASENAME}"
SUITE="${SUITE:-noble}"  # Ubuntu 24.04 (Noble Numbat)
MIRROR="${MIRROR:-http://ubuntutym.u-toyama.ac.jp/ubuntu}"
ARCH="${ARCH:-amd64}"

TARGET_DIR="../work_build/$BASENAME"

# 実行ログ
echo "[$SCRIPT_NAME] SUITE: $SUITE"
echo "[$SCRIPT_NAME] MIRROR: $MIRROR"
echo "[$SCRIPT_NAME] ARCH: $ARCH"
echo "[$SCRIPT_NAME] TARGET_DIR: $TARGET_DIR"

# debootstrap 実行
debootstrap --arch="$ARCH" "$SUITE" "$TARGET_DIR" "$MIRROR"

echo "[$SCRIPT_NAME] Ubuntu $SUITE のベースシステム構築が完了しました"

