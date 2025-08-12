#!/bin/bash
set -e

if [ $EUID != 0 ]; then
    echo "[ERROR]: root privilege is required, but you're not root. Try again with sudo."
    exit 1
fi