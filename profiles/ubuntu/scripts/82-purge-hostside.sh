#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
CHROOT_DIR="${WORK_DIR}/$BASENAME"  

echo "[$SCRIPT_NAME] Cleaning up unnecessary files out of the chroot directory... (Target: $CHROOT_DIR)"

# ----------------------------------------
# Delete APT cache and package lists
# ----------------------------------------
rm -rf "$CHROOT_DIR/var/cache/apt/archives"/*
rm -rf "$CHROOT_DIR/var/lib/apt/lists"/*

# ----------------------------------------
# Delete temporary files
# ----------------------------------------
rm -rf "$CHROOT_DIR/tmp"/*
rm -rf "$CHROOT_DIR/var/tmp"/*

# ----------------------------------------
# Delete Flatpak cache (excluding fontconfig)
# ----------------------------------------
# Clean up regular users' Flatpak cache
for user_dir in "$CHROOT_DIR/home/"*; do
    app_cache_base="$user_dir/.var/app"
    if [[ -d "$app_cache_base" ]]; then
        for app_dir in "$app_cache_base"/*; do
            cache_dir="$app_dir/cache"
            if [[ -d "$cache_dir" ]]; then
                # Find all files/directories in cache_dir, excluding 'fontconfig', and delete them
                find "$cache_dir" -mindepth 1 -maxdepth 1 ! -name "fontconfig" -exec rm -rf {} +
                echo "  → Deleted: everything except fontconfig in $cache_dir"
            fi
        done
    fi
done

# Clean up root user's Flatpak cache
if [[ -d "$CHROOT_DIR/root/.var/app" ]]; then
    for app_dir in "$CHROOT_DIR/root/.var/app"/*; do
        cache_dir="$app_dir/cache"
        if [[ -d "$cache_dir" ]]; then
            # Find all files/directories in cache_dir, excluding 'fontconfig', and delete them
            find "$cache_dir" -mindepth 1 -maxdepth 1 ! -name "fontconfig" -exec rm -rf {} +
            echo "  → Deleted: everything except fontconfig in $cache_dir"
        fi
    done
fi

# ----------------------------------------
# Delete unnecessary documents, man pages, and info files
# ----------------------------------------
rm -rf "$CHROOT_DIR/usr/share/doc"/*
#rm -rf "$CHROOT_DIR/usr/share/man"/*
rm -rf "$CHROOT_DIR/usr/share/info"/*

# ----------------------------------------
# Delete log files and recreate the minimum necessary
# ----------------------------------------
rm -rf "$CHROOT_DIR/var/log"/*
mkdir -p "$CHROOT_DIR/var/log"
touch "$CHROOT_DIR/var/log/dpkg.log"

echo "[$SCRIPT_NAME] Unnecessary files in the host has been deleted successfully"