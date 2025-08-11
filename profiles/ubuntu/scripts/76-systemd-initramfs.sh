#!/bin/bash
set -e
SCRIPT_NAME="$(basename "$0")"
echo "[${SCRIPT_NAME}] initrd.img を再生成します..."

KERNEL_VERSION=$(ls /lib/modules | sort -V | tail -n 1)
echo "使用カーネルバージョン: $KERNEL_VERSION"

if [ ! -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
  echo "vmlinuz が存在しません。再インストールを行います..."
  apt install --reinstall "linux-image-$KERNEL_VERSION"
fi


# initramfs.conf の INIT を systemd に設定（既存の INIT= を置換または追記）
    echo 'INIT=init' >> /etc/initramfs-tools/initramfs.conf

# /etc/hostname（systemd の初期化に必要）
echo "livermorium" > /etc/hostname

# machine-id の初期化
systemd-machine-id-setup

# initrd.img を再生成
update-initramfs -c -k "$KERNEL_VERSION"

# /init が生成されたか確認（警告として表示）
if lsinitramfs "/boot/initrd.img-$KERNEL_VERSION" | grep -q '^init$'; then
    echo "✓ /init が含まれています"
else
    echo "⚠ /init が含まれていません！（カーネルパニックの原因になる可能性あり）"
    exit 1
fi

echo "[${SCRIPT_NAME}] 完了"
