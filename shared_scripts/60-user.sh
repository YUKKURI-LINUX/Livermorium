#!/bin/bash

set -e

# ユーザー名とパスワード、グループを読み込む
USERNAME="${USERNAME:-livermorium}"
PASSWORD="${PASSWORD:-livermorium}"
USER_GROUPS="${USER_GROUPS:-wheel}"

echo "[INFO] ユーザー '$USERNAME' を作成中..."
echo "[INFO] グループ: $USER_GROUPS"

# グループが存在しなければ作成
for group in $USER_GROUPS; do
    if ! getent group "$group" > /dev/null 2>&1; then
        echo "[INFO] グループ '$group' を作成"
        groupadd "$group"
    fi
done

# ユーザーが既に存在するか確認
if id "$USERNAME" &>/dev/null; then
    echo "[WARN] ユーザー '$USERNAME' は既に存在します"
else
    # ユーザーを作成
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "[INFO] ユーザー '$USERNAME' を作成しました"
fi

# グループにユーザーを追加
for group in $USER_GROUPS; do
    usermod -aG "$group" "$USERNAME"
done

echo "[INFO] '$USERNAME' をグループ '$USER_GROUPS' に追加しました"
