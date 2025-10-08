#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

# Mandatory check: BASENAME must be defined
: "${BASENAME:?BASENAME is undefined}"
ISO_DIR="${WORK_DIR}/iso/${BASENAME}"
GRUB_DIR="${ISO_DIR}/boot/grub"
I386_DIR="${GRUB_DIR}/i386-pc"
GRUB_CFG="${GRUB_DIR}/grub.cfg"

# Check if grub.cfg exists
[ -f "${GRUB_CFG}" ] || { echo "[85] ${GRUB_CFG} is missing (run 84 first)"; exit 1; }

# Prepare directories
mkdir -p "${I386_DIR}"
rm -f "${I386_DIR}/core.img" "${I386_DIR}/eltorito.img"

# Locate cdboot.img
CDBOOT_IMG="${CDBOOT_IMG:-/usr/lib/grub/i386-pc/cdboot.img}"
# Fallback search using dpkg
[ -f "${CDBOOT_IMG}" ] || CDBOOT_IMG="$(dpkg -L grub-pc-bin 2>/dev/null | grep '/i386-pc/cdboot.img$' | head -n1 || true)"
[ -f "${CDBOOT_IMG}" ] || { echo "[$SCRIPT_NAME] cdboot.img not found. Please specify CDBOOT_IMG."; exit 1; }

# --- Place all i386-pc modules on the ISO side ---
# This allows 'core' to be minimal, as required modules can be loaded from here at runtime.
if [ ! -d "${I386_DIR}" ] || [ -z "$(ls -A "${I386_DIR}" 2>/dev/null)" ]; then
  mkdir -p "${I386_DIR}"
fi
# Copy all modules (can be pruned later to reduce size)
cp -a /usr/lib/grub/i386-pc/*.mod "${I386_DIR}/" 2>/dev/null || true

# --- Generate minimal core.img using mkimage ---
# The prefix is (cd)/boot/grub, pointing to the grub directory on the ISO.
# Modules are truly minimal (others can be loaded from the ISO).
CORE_MODULES=("biosdisk" "part_msdos" "part_gpt" "iso9660" "normal" "linux" "search" "configfile")
grub-mkimage \
  -O i386-pc \
  -p '(cd)/boot/grub' \
  -o "${I386_DIR}/core.img" \
  "${CORE_MODULES[@]}"

# Create El Torito boot image
cat "${CDBOOT_IMG}" "${I386_DIR}/core.img" > "${I386_DIR}/eltorito.img"
echo "[$SCRIPT_NAME] Created eltorito.img for BIOS: ${I386_DIR}/eltorito.img"