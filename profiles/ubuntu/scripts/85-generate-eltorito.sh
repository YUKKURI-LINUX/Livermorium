#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

WORK_DIR="${WORK_DIR:-../work_build}"
: "${BASENAME:?BASENAME が未定義です}"   # 必須
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
I386_DIR="${GRUB_DIR}/i386-pc"
GRUB_CFG="${GRUB_DIR}/grub.cfg"

[ -f "${GRUB_CFG}" ] || { echo "[85] ${GRUB_CFG} がありません（84を先に実行）"; exit 1; }

mkdir -p "${I386_DIR}"
rm -f "${I386_DIR}/core.img" "${I386_DIR}/eltorito.img"

# cdboot.img の所在
CDBOOT_IMG="${CDBOOT_IMG:-/usr/lib/grub/i386-pc/cdboot.img}"
[ -f "${CDBOOT_IMG}" ] || CDBOOT_IMG="$(dpkg -L grub-pc-bin 2>/dev/null | grep '/i386-pc/cdboot.img$' | head -n1 || true)"
[ -f "${CDBOOT_IMG}" ] || { echo "[$SCRIPT_NAME] cdboot.img が見つかりません。CDBOOT_IMG を指定してください。"; exit 1; }

# --- ISO 側に i386-pc モジュール一式を配置 ---
# これがあるから core は極小でOK（必要なものは実行時にここからロード）
if [ ! -d "${I386_DIR}" ] || [ -z "$(ls -A "${I386_DIR}" 2>/dev/null)" ]; then
  mkdir -p "${I386_DIR}"
fi
# 必要なら一式コピー（容量を絞るなら後で間引き）
cp -a /usr/lib/grub/i386-pc/*.mod "${I386_DIR}/" 2>/dev/null || true

# --- 最小構成の core.img を mkimage で生成 ---
# prefix は (cd)/boot/grub → ISO 上の grub ディレクトリを見る
# モジュールは本当に最小限（ISO上から他はロード可能）
CORE_MODULES=("biosdisk" "part_msdos" "part_gpt" "iso9660" "normal" "linux" "search" "configfile")
grub-mkimage \
  -O i386-pc \
  -p '(cd)/boot/grub' \
  -o "${I386_DIR}/core.img" \
  "${CORE_MODULES[@]}"

# El Torito イメージ作成
cat "${CDBOOT_IMG}" "${I386_DIR}/core.img" > "${I386_DIR}/eltorito.img"
echo "[$SCRIPT_NAME] BIOS用 eltorito.img 作成: ${I386_DIR}/eltorito.img"

