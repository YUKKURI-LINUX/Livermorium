#!/bin/bash
set -e

SCRIPT_NAME=$(basename "$0")
echo "[$SCRIPT_NAME] 必要な systemd サービスを有効化します"

#ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# ディスプレイマネージャの自動有効化
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

#if command -v lightdm &>/dev/null; then
#    echo "[$SCRIPT_NAME] lightdm を有効化します"
#    systemctl enable lightdm
#elif command -v gdm3 &>/dev/null; then
#    echo "[$SCRIPT_NAME] gdm3 を有効化します"
#    systemctl enable gdm3
#elif command -v gdm &>/dev/null; then
#    echo "[$SCRIPT_NAME] gdm を有効化します"
#    systemctl enable gdm
#elif command -v sddm &>/dev/null; then
#    echo "[$SCRIPT_NAME] sddm を有効化します"
#    systemctl enable sddm
#else
#    echo "[$SCRIPT_NAME] ディスプレイマネージャが見つかりません"
#fi

# ネットワークマネージャ
if systemctl list-unit-files | grep -q NetworkManager.service; then
    echo "[$SCRIPT_NAME] NetworkManager を有効化します"
    systemctl enable NetworkManager
elif systemctl list-unit-files | grep -q wicked.service; then
    echo "[$SCRIPT_NAME] wicked を有効化します"
    systemctl enable wicked
elif systemctl list-unit-files | grep -q systemd-networkd.service; then
    echo "[$SCRIPT_NAME] systemd-networkd を有効化します"
    systemctl enable systemd-networkd
else
    echo "[$SCRIPT_NAME] ネットワークサービスが見つかりません"
fi

# Bluetooth
if systemctl list-unit-files | grep -q bluetooth.service; then
    echo "[$SCRIPT_NAME] bluetooth を有効化します"
    systemctl enable bluetooth
fi

# Printing
if systemctl list-unit-files | grep -q cups.service; then
    echo "[$SCRIPT_NAME] cups を有効化します"
    systemctl enable cups
fi

echo "[$SCRIPT_NAME] systemd サービスの有効化が完了しました"

