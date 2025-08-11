#!/bin/bash
set -e

echo "[65-packages.sh] パッケージと Flatpak アプリのインストールを開始..."

# === Universe, Multiverse リポジトリの追加（Ubuntu Noble は必要最小構成なので明示的に追加）===
if ! grep -q "noble universe" /etc/apt/sources.list; then
    echo "[INFO] universe/multiverse を sources.list に追加します"
    cat <<EOF >> /etc/apt/sources.list

deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
fi

# === パッケージリストの更新 ===
apt update

# === 通常のパッケージをインストール ===
if [ -n "$PACKAGE_LIST" ]; then
    echo "[INFO] 通常パッケージのインストール: $PACKAGE_LIST"
    apt install -y $PACKAGE_LIST
fi

apt upgrade -y

# === Flatpak の導入がまだならインストール ===
if ! command -v flatpak > /dev/null; then
    echo "[INFO] Flatpak が見つかりません。インストールします..."
    apt install -y flatpak || {
        echo "[ERROR] flatpak のインストールに失敗しました"
        exit 1
    }
fi

# === bwrapの
chmod u+s $(which bwrap)


# === Flathub の登録 ===
if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# === Flatpak アプリをインストール ===
if [ -n "$FLATPAK_LIST" ]; then
    echo "[INFO] Flatpak アプリのインストール: $FLATPAK_LIST"
    for app in $FLATPAK_LIST; do
        flatpak install -y flathub "$app"
       ##もじばけかいひ 
        #flatpak run --command=fc-cache $app -f -v 

    done

    # Flatpakアプリにfcitx5用環境変数を設定
    echo "[65-packages.sh] Flatpakにfcitx5用環境変数を設定..."
    flatpak override --system \
        --env=GTK_IM_MODULE=fcitx \
        --env=QT_IM_MODULE=fcitx \
        --env=XMODIFIERS=@im=fcitx \
        --env=INPUT_METHOD=fcitx

fi
