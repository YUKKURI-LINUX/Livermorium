#!/bin/bash
set -e

SCRIPT_NAME="$(basename "$0")"


WORK_DIR="../work_build"
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
EFI_DIR="${ISO_DIR}/EFI/boot"

mkdir -p "${GRUB_DIR}" "${EFI_DIR}"

cat > "${GRUB_DIR}/grub.cfg" <<'EOF'
set default=0
set timeout=5
set timeout_style=menu

# ルート探索（USB/仮想/loopbackでも安定）
search --no-floppy --file --set=root /casper/filesystem.squashfs

menuentry "Start Live (GNOME, casper)" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "Start Live (Text mode, debug)" {
    linux /casper/vmlinuz boot=casper text ---
    initrd /casper/initrd
}
EOF

install -m 0644 -D "${GRUB_DIR}/grub.cfg" "${EFI_DIR}/grub.cfg"
echo "[$SCRIPT_NAME] grub.cfg 作成: ${GRUB_DIR}/grub.cfg, ${EFI_DIR}/grub.cfg"
