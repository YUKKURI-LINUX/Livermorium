#!/usr/bin/env bash
set -Eeuo pipefail
# -----------------------------------------------------------------------------
# Livermorium GUI 一括インストーラー
# 対応: Ubuntu / Debian / Arch / openSUSE / Fedora
#
# すること:
#   1) 依存導入（PyGObject / GTK4 / libadwaita / GtkSourceView / polkit 等）
#      ※ polkit は GUI から cl_main.py を root で呼ぶ際（pkexec）に利用
#   2) 起動ラッパー作成 (/usr/local/bin/<APP_CLI_NAME>) ※ pkexec は使わず main.py をユーザー権限で実行
#   3) .desktop 登録 (/usr/local/share/applications/<APP_ID>.desktop)
#   4) アイコンを hicolor に一括コピー（PNG 各サイズ + scalable の SVG）
#   5) デスクトップDB / アイコンキャッシュ更新
#
# 前提:
#   - このスクリプトと main.py は同じディレクトリ（= リポジトリ直下）
#   - アイコンは ./assets/icons/ に hicolor 構成で用意
#     例) assets/icons/16x16/apps/<APP_ID>.png
#         assets/icons/32x32/apps/<APP_ID>.png
#         ...
#         assets/icons/scalable/apps/<APP_ID>.svg
# -----------------------------------------------------------------------------

# ==========================
# 1) 既定値
# ==========================
APP_ID="dev.livermorium.gui"
APP_NAME="Livermorium"
APP_CLI_NAME="livermorium-gui"
PREFIX="/usr/local"

COMMENT="Build tool for multi-distro ISO images."
CATEGORIES="System;Utility;"
TERMINAL="false"

# ==========================
# 2) スクリプト位置から自動解決
# ==========================
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
APP_MAIN="${SCRIPT_DIR}/main.py"      # ラッパーが起動する GUI 本体
ASSET_ROOT="${SCRIPT_DIR}/assets"
ICON_SRC_DIR="${ASSET_ROOT}/icons"    # この配下を hicolor にそのままコピー（PNG+SVG）

# ==========================
# 3) インストール先
# ==========================
BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share"
DESKTOP_DIR="${SHARE_DIR}/applications"
ICON_DIR="${SHARE_DIR}/icons/hicolor"  # hicolor のみ（pixmaps は使用しない）

# ==========================
# 4) ユーティリティ
# ==========================
log()  { printf "\033[1;36m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
die()  { err "$1"; exit 1; }
exists(){ command -v "$1" >/dev/null 2>&1; }

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "root 権限が必要です。sudo で実行してください。"
  fi
}

read_os() {
  if [ ! -f /etc/os-release ]; then
    die "/etc/os-release が見つかりません。"
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID}"
  OS_ID_LIKE="${ID_LIKE:-}"
  log "Detected OS: ${OS_ID} (like: ${OS_ID_LIKE})"
}

# ==========================
# 5) 依存パッケージ（ディストロ別）
# ==========================
DEPS_UBUNTU=(
   python3 python3-gi
  # GObject Introspection の GI バインディング
  gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5
  # ランタイムライブラリ（gtk4 / libadwaita / gtksourceview5）
  libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0
  # ユーティリティ
  libglib2.0-bin desktop-file-utils
  # pkexec（GUI→cl_main.py をroot起動する用途）
  policykit-1
)
DEPS_DEBIAN=(
  python3 python3-gi
  gir1.2-gtk-4.0
  gir1.2-adw-1
  gir1.2-gtksource-5
  libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0
  libglib2.0-bin desktop-file-utils
  policykit-1
)
DEPS_ARCH=(
  python
  python-gobject
  gtk4 libadwaita gtksourceview5
  gobject-introspection
  desktop-file-utils
  polkit
)
DEPS_FEDORA=(
  python3
  python3-gobject
  gtk4 libadwaita gtksourceview5
  gobject-introspection
  glib2
  desktop-file-utils
  polkit
)
DEPS_OPENSUSE=(
  python3
  python3-gobject
  gtk4 libadwaita-1_0 gtksourceview5
  gobject-introspection
  glib2-tools
  desktop-file-utils
  polkit
)

# ==========================
# 6) 依存導入
# ==========================
install_deps_ubuntu() {
  if ! exists apt; then die "apt が見つかりません（Ubuntu）。"; fi
  log "apt update を実行します..."
  apt update
  log "Ubuntu の依存パッケージをインストールします..."
  apt install -y "${DEPS_UBUNTU[@]}"
}
install_deps_debian() {
  if ! exists apt; then die "apt が見つかりません（Debian）。"; fi
  log "apt update を実行します..."
  apt update
  log "Debian の依存パッケージを確認しつつインストールします..."
  local pkgs=()
  for pkg in "${DEPS_DEBIAN[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      pkgs+=("$pkg")
    else
      warn "スキップ: $pkg"
    fi
  done
  if [ "${#pkgs[@]}" -gt 0 ]; then
    apt install -y "${pkgs[@]}"
  else
    warn "インストール対象がありませんでした。"
  fi
}
install_deps_arch() {
  if ! exists pacman; then die "pacman が見つかりません（Arch）。"; fi
  log "pacman -Sy を実行します..."
  pacman -Sy
  log "Arch の依存パッケージをインストールします..."
  pacman -S --needed --noconfirm "${DEPS_ARCH[@]}"
}
install_deps_fedora() {
  if ! exists dnf; then die "dnf が見つかりません（Fedora）。"; fi
  log "dnf makecache を実行します..."
  dnf makecache -y
  log "Fedora の依存パッケージをインストールします..."
  dnf install -y "${DEPS_FEDORA[@]}"
}
install_deps_opensuse() {
  if ! exists zypper; then die "zypper が見つかりません（openSUSE）。"; fi
  log "zypper refresh を実行します..."
  zypper --non-interactive refresh
  log "openSUSE の依存パッケージをインストールします..."
  for pkg in "${DEPS_OPENSUSE[@]}"; do
    if zypper --non-interactive install "$pkg"; then
      :
    else
      warn "見つからない/失敗: $pkg（続行）"
    fi
  done
}
install_deps() {
  log "依存導入を開始します..."
  case "${OS_ID}" in
    ubuntu)   install_deps_ubuntu   ;;
    debian)   install_deps_debian   ;;
    arch)     install_deps_arch     ;;
    fedora)   install_deps_fedora   ;;
    opensuse*|suse|sles) install_deps_opensuse ;;
    *)
      if printf %s "${OS_ID_LIKE}" | grep -qi debian; then
        warn "正式未対応: Debian系として試行します。"; install_deps_ubuntu || true
      else
        warn "未対応ディストロ。依存導入はスキップします。"
      fi
      ;;
  esac
}

# ==========================
# 7) ラッパー生成
# ==========================
wrapper_path() { echo "${BIN_DIR}/${APP_CLI_NAME}"; }

install_wrapper() {
  if [ ! -f "${APP_MAIN}" ]; then
    warn "main.py が見つかりません: ${APP_MAIN}（後で配置 → 再実行で更新）"
  fi

  log "起動ラッパーを生成します: $(wrapper_path)"
  mkdir -p "${BIN_DIR}"

  cat >"$(wrapper_path)" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# GUI 本体（repo 直下 main.py）をユーザー権限で起動
PYTHON="${PYTHON:-python3}"
APP_MAIN="__APP_MAIN__"

exec "${PYTHON}" "${APP_MAIN}" "$@"
EOF

  sed -i "s|__APP_MAIN__|${APP_MAIN}|g" "$(wrapper_path)"
  chmod 0755 "$(wrapper_path)"
}

# ==========================
# 8) .desktop 登録（Icon は拡張子なし）
# ==========================
install_desktop() {
  log ".desktop を登録します: ${DESKTOP_DIR}/${APP_ID}.desktop"
  mkdir -p "${DESKTOP_DIR}"
  cat > "${DESKTOP_DIR}/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=${COMMENT}
Exec=$(wrapper_path)
Icon=${APP_ID}
Terminal=${TERMINAL}
Categories=${CATEGORIES}
StartupNotify=true
X-GNOME-UsesNotifications=true
EOF
  chmod 0644 "${DESKTOP_DIR}/${APP_ID}.desktop"
}

# ==========================
# 9) アイコン配置（PNG+SVG を hicolor に丸ごとコピー）
# ==========================
install_icons() {
  if [ ! -d "${ICON_SRC_DIR}" ]; then
    warn "アイコンソースが見つかりません（${ICON_SRC_DIR}）。スキップします。"
    return 0
  fi

  # 簡単 & 確実：用意した hicolor 構成をそのままコピー
  log "hicolor へアイコンを一括コピーします: ${ICON_SRC_DIR} -> ${ICON_DIR}"
  mkdir -p "${ICON_DIR}"
  cp -a "${ICON_SRC_DIR}/." "${ICON_DIR}/"
}

# ==========================
# 10) キャッシュ更新
# ==========================
update_caches() {
  if exists update-desktop-database; then
    log "desktop-file データベース更新（update-desktop-database）..."
    update-desktop-database "${SHARE_DIR}/applications" || true
  fi
  if exists gtk-update-icon-cache; then
    log "アイコンキャッシュ更新（gtk-update-icon-cache）..."
    gtk-update-icon-cache -q -t -f "${SHARE_DIR}/icons/hicolor" || true
  fi
}

# ==========================
# 11) アンインストール（PNG+SVG を明示的に削除）
# ==========================
uninstall_all() {
  log "アンインストールを実行します..."

  # .desktop とラッパー
  rm -f "${DESKTOP_DIR}/${APP_ID}.desktop" || true
  rm -f "$(wrapper_path)" || true

  # PNG と SVG（決め打ちで）
  rm -f "${ICON_DIR}/*/apps/${APP_ID}.png" 2>/dev/null || true
  rm -f "${ICON_DIR}/scalable/apps/${APP_ID}.svg" 2>/dev/null || true

  update_caches
  log "アンインストール完了。"
}

# ==========================
# 12) メイン処理
# ==========================
main() {
  need_root
  read_os

  if [ "${1:-}" = "--uninstall" ]; then
    uninstall_all
    exit 0
  fi

  install_deps
  install_wrapper
  install_desktop
  install_icons
  update_caches

  cat <<EOF

== セットアップ完了 ==
起動コマンド : ${APP_CLI_NAME}
.desktop     : ${DESKTOP_DIR}/${APP_ID}.desktop
アイコン       : ${ICON_DIR}/...

※ ラッパーはユーザー権限で ${APP_MAIN} を起動します。
※ GUI 内で root が必要な処理（cl_main.py 実行など）に pkexec（polkit）を使ってください。
※ リポジトリの場所が変わったら、このスクリプトを同じ場所で再実行してください（上書き更新）。

アンインストール:
  sudo $(basename "$0") --uninstall

EOF
}

main "$@"
