#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"
CHROOT_DIR="../work_build/$BASENAME"  

echo "[$SCRIPT_NAME] chroot外での不要ファイル削除を開始（対象: $CHROOT_DIR）"

# ----------------------------------------
# APT関連キャッシュ・リスト削除
# ----------------------------------------
rm -rf "$CHROOT_DIR/var/cache/apt/archives"/*
rm -rf "$CHROOT_DIR/var/lib/apt/lists"/*

# ----------------------------------------
# 一時ファイル削除
# ----------------------------------------
rm -rf "$CHROOT_DIR/tmp"/*
rm -rf "$CHROOT_DIR/var/tmp"/*

# ----------------------------------------
# Flatpakキャッシュ削除（fontconfig を除外）
# ----------------------------------------
for user_dir in "$CHROOT_DIR/home/"*; do
    app_cache_base="$user_dir/.var/app"
    if [[ -d "$app_cache_base" ]]; then
        for app_dir in "$app_cache_base"/*; do
            cache_dir="$app_dir/cache"
            if [[ -d "$cache_dir" ]]; then
                find "$cache_dir" -mindepth 1 -maxdepth 1 ! -name "fontconfig" -exec rm -rf {} +
                echo "  → 削除: $cache_dir の fontconfig 以外"
            fi
        done
    fi
done

# rootユーザーの Flatpakキャッシュ削除
if [[ -d "$CHROOT_DIR/root/.var/app" ]]; then
    for app_dir in "$CHROOT_DIR/root/.var/app"/*; do
        cache_dir="$app_dir/cache"
        if [[ -d "$cache_dir" ]]; then
            find "$cache_dir" -mindepth 1 -maxdepth 1 ! -name "fontconfig" -exec rm -rf {} +
            echo "  → 削除: $cache_dir の fontconfig 以外"
        fi
    done
fi

# ----------------------------------------
# 不要なドキュメント・man・info削除
# ----------------------------------------
rm -rf "$CHROOT_DIR/usr/share/doc"/*
#rm -rf "$CHROOT_DIR/usr/share/man"/*
rm -rf "$CHROOT_DIR/usr/share/info"/*

# ----------------------------------------
# ログファイル削除と最低限の再作成
# ----------------------------------------
rm -rf "$CHROOT_DIR/var/log"/*
mkdir -p "$CHROOT_DIR/var/log"
touch "$CHROOT_DIR/var/log/dpkg.log"

echo "[$SCRIPT_NAME] ホスト側からのクリーンアップ完了"
