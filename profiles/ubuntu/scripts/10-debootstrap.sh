#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Creating a new minimal installation of Ubuntu..."

# Get variables (with default values).
BASENAME="${BASENAME}"
SUITE="${SUITE:-noble}"  # Default: Ubuntu 24.04 (Noble Numbat)
MIRROR="${MIRROR:-http://ftp.riken.go.jp/Linux/ubuntu}"
ARCH="${ARCH:-amd64}"

TARGET_DIR="${WORK_DIR}/$BASENAME"

# Show arguments.
echo "[$SCRIPT_NAME] SUITE: $SUITE"
echo "[$SCRIPT_NAME] MIRROR: $MIRROR"
echo "[$SCRIPT_NAME] ARCH: $ARCH"
echo "[$SCRIPT_NAME] TARGET_DIR: $TARGET_DIR"

# Execute debootstrap.
debootstrap --arch="$ARCH" "$SUITE" "$TARGET_DIR" "$MIRROR"

echo "[$SCRIPT_NAME] A new base system of 'Ubuntu $SUITE' is installed successfully."
