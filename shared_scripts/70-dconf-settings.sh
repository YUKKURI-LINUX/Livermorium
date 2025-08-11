#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] GNOME dconf 設定を反映中..."

# /etc/dconf/profile/user が必要
echo "user-db:user\nsystem-db:local" > /etc/dconf/profile/user

# 設定ファイルがない場合スキップ
if  [ -f  /etc/dconf/db/local.d ]; then

    # dconf update
    if command -v dconf >/dev/null 2>&1; then
        dconf update
    fi

    echo "[$SCRIPT_NAME] dconf 設定完了"
    
else
    echo "[$SCRIPT_NAME] dconf 設定スキップ"
fi
