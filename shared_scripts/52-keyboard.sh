#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] キーボード設定の設定を開始..."

# /etc/default/keyboard を生成
cat >/etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYBOARD}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# debconf の非対話再設定（systemd不要）
debconf-set-selections <<EOF
keyboard-configuration keyboard-configuration/layoutcode string ${KEYBOARD}
keyboard-configuration keyboard-configuration/xkb-keymap select ${KEYBOARD}
keyboard-configuration keyboard-configuration/modelcode string pc105
keyboard-configuration keyboard-configuration/variantcode string
keyboard-configuration keyboard-configuration/optionscode string
EOF

DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive keyboard-configuration || true



echo "[$SCRIPT_NAME] キーボード設定の設定完了"
