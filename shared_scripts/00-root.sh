#!/bin/bash
set -e

if [ $EUID != 0 ]; then
    echo "[FATAL]: root privileges are required, but you are not root. Try again with sudo."
    exit 1
fi