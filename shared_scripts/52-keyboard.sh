#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Setting up the keyboard..."

# Generate /etc/default/keyboard
cat >/etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYBOARD}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# Non-interactive reconfigure of debconf (no systemd needed)
debconf-set-selections <<EOF
keyboard-configuration keyboard-configuration/layoutcode string ${KEYBOARD}
keyboard-configuration keyboard-configuration/xkb-keymap select ${KEYBOARD}
keyboard-configuration keyboard-configuration/modelcode string pc105
keyboard-configuration keyboard-configuration/variantcode string
keyboard-configuration keyboard-configuration/optionscode string
EOF

# Reconfigure the keyboard-configuration package non-interactively
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive keyboard-configuration || true


echo "[$SCRIPT_NAME] Keyboard configuration is set up successfully."