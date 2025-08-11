#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] ロケールとタイムゾーンの設定を開始..."


# 余分な空白を除去（Bad entry対策）
LOCALE="$(echo "$LOCALE" | xargs)"

echo "[$SCRIPT_NAME] LOCALE=$LOCALE TIMEZONE=$TIMEZONE"

# locale.gen に追記（重複防止）
sed -i "/^#\?\s*${LOCALE//./\\.}\s*$/d" /etc/locale.gen
echo "$LOCALE UTF-8" >> /etc/locale.gen

# 生成＆システム既定に反映
locale-gen
update-locale LANG="$LOCALE"

# LANGUAGE を LOCALE から生成
# 例: ja_JP.UTF-8 → ja_JP:ja
LANG_CODE="${LOCALE%%.*}"   # ja_JP
BASE_LANG="${LANG_CODE%%_*}" # ja
LANGUAGE_VALUE="${LANG_CODE}:${BASE_LANG}"

# /etc/default/locale にも明示（GUIが参照）
cat >/etc/default/locale <<EOF
LANG=$LOCALE
LANGUAGE=$LANGUAGE_VALUE
LC_CTYPE=$LOCALE
LC_ALL=
EOF

# タイムゾーン（対話なし）
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone

echo "[$SCRIPT_NAME] ロケールとタイムゾーンの設定完了"
