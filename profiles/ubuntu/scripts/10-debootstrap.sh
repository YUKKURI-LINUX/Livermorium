#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting Ubuntu base system construction..."

# Get environment variables (with default values)
BASENAME="${BASENAME}"
SUITE="${SUITE:-noble}"  # Ubuntu 24.04 (Noble Numbat)
MIRROR="${MIRROR:-http://ubuntutym.u-toyama.ac.jp/ubuntu}"
ARCH="${ARCH:-amd64}"

TARGET_DIR="${WORK_DIR}/$BASENAME"

# Execution log
echo "[$SCRIPT_NAME] SUITE: $SUITE"
echo "[$SCRIPT_NAME] MIRROR: $MIRROR"
echo "[$SCRIPT_NAME] ARCH: $ARCH"
echo "[$SCRIPT_NAME] TARGET_DIR: $TARGET_DIR"

# Execute debootstrap
debootstrap --arch="$ARCH" "$SUITE" "$TARGET_DIR" "$MIRROR"

echo "[$SCRIPT_NAME] Ubuntu $SUITE base system construction is complete"