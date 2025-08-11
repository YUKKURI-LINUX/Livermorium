#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] ロケールとタイムゾーンの設定を開始..."

# ロケールの設定
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=$LOCALE

# タイムゾーン設定
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone

# locale.conf（Arch）
echo "LANG=$LOCALE" > /etc/locale.conf

echo "[$SCRIPT_NAME] ロケールとタイムゾーンの設定完了"
