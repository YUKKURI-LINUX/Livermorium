#!/usr/bin/env bash
set -Eeuo pipefail
# -----------------------------------------------------------------------------
# Livermorium GUI Batch Installer
# Supported: Ubuntu / Debian / Arch / openSUSE / Fedora
#
# Actions:
#   1) Install dependencies (PyGObject / GTK4 / libadwaita / GtkSourceView / polkit, etc.)
#      * polkit is used when calling cl_main.py from the GUI as root (via pkexec)
#   2) Create startup wrapper (/usr/local/bin/<APP_CLI_NAME>) * Executes main.py with user privileges, no pkexec
#   3) Register .desktop file (/usr/local/share/applications/<APP_ID>.desktop)
#   4) Batch copy icons to hicolor (PNG in various sizes + scalable SVG)
#   5) Update desktop DB / icon cache
#
# Prerequisites:
#   - This script and main.py are in the same directory (= repository root)
#   - Icons are provided in ./assets/icons/ with hicolor structure
#     E.g.) assets/icons/16x16/apps/<APP_ID>.png
#           assets/icons/32x32/apps/<APP_ID>.png
#           ...
#           assets/icons/scalable/apps/<APP_ID>.svg
# -----------------------------------------------------------------------------

# ==========================
# 1) Default Values
# ==========================
APP_ID="dev.livermorium.gui"
APP_NAME="Livermorium"
APP_CLI_NAME="livermorium-gui"
PREFIX="/usr/local"

COMMENT="Build tool for multi-distro ISO images."
CATEGORIES="System;Utility;"
TERMINAL="false"

# ==========================
# 2) Automatic Resolution from Script Location
# ==========================
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
APP_MAIN="${SCRIPT_DIR}/main.py"      # The main GUI file launched by the wrapper
ASSET_ROOT="${SCRIPT_DIR}/assets"
ICON_SRC_DIR="${ASSET_ROOT}/icons"    # This content is copied directly to hicolor (PNG+SVG)

# ==========================
# 3) Installation Destinations
# ==========================
BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share"
DESKTOP_DIR="${SHARE_DIR}/applications"
ICON_DIR="${SHARE_DIR}/icons/hicolor"  # Only hicolor (pixmaps is not used)

# ==========================
# 4) Utilities
# ==========================
log()  { printf "\033[1;36m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
die()  { err "$1"; exit 1; }
exists(){ command -v "$1" >/dev/null 2>&1; }

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "Root privileges are required. Please run with sudo."
  fi
}

read_os() {
  if [ ! -f /etc/os-release ]; then
    die "/etc/os-release not found."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID}"
  OS_ID_LIKE="${ID_LIKE:-}"
  log "Detected OS: ${OS_ID} (like: ${OS_ID_LIKE})"
}

# ==========================
# 5) Dependencies (Per Distribution)
# ==========================
DEPS_UBUNTU=(
   python3 python3-gi
  # GObject Introspection GI bindings
  gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5
  # Runtime libraries (gtk4 / libadwaita / gtksourceview5)
  libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0
  # Utilities
  libglib2.0-bin desktop-file-utils
  # pkexec (for running cl_main.py as root from the GUI)
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
# 6) Install Dependencies
# ==========================
install_deps_ubuntu() {
  if ! exists apt; then die "apt not found (Ubuntu)."; fi
  log "Running apt update..."
  apt update
  log "Installing Ubuntu dependencies..."
  apt install -y "${DEPS_UBUNTU[@]}"
}
install_deps_debian() {
  if ! exists apt; then die "apt not found (Debian)."; fi
  log "Running apt update..."
  apt update
  log "Checking for and installing Debian dependencies..."
  local pkgs=()
  for pkg in "${DEPS_DEBIAN[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      pkgs+=("$pkg")
    else
      warn "Skipping: $pkg"
    fi
  done
  if [ "${#pkgs[@]}" -gt 0 ]; then
    apt install -y "${pkgs[@]}"
  else
    warn "No packages found for installation."
  fi
}
install_deps_arch() {
  if ! exists pacman; then die "pacman not found (Arch)."; fi
  log "Running pacman -Sy..."
  pacman -Sy
  log "Installing Arch dependencies..."
  pacman -S --needed --noconfirm "${DEPS_ARCH[@]}"
}
install_deps_fedora() {
  if ! exists dnf; then die "dnf not found (Fedora)."; fi
  log "Running dnf makecache..."
  dnf makecache -y
  log "Installing Fedora dependencies..."
  dnf install -y "${DEPS_FEDORA[@]}"
}
install_deps_opensuse() {
  if ! exists zypper; then die "zypper not found (openSUSE)."; fi
  log "Running zypper refresh..."
  zypper --non-interactive refresh
  log "Installing openSUSE dependencies..."
  for pkg in "${DEPS_OPENSUSE[@]}"; do
    if zypper --non-interactive install "$pkg"; then
      :
    else
      warn "Not found/Failed: $pkg (Continuing)"
    fi
  done
}
install_deps() {
  log "Starting dependency installation..."
  case "${OS_ID}" in
    ubuntu)   install_deps_ubuntu   ;;
    debian)   install_deps_debian   ;;
    arch)     install_deps_arch     ;;
    fedora)   install_deps_fedora   ;;
    opensuse*|suse|sles) install_deps_opensuse ;;
    *)
      if printf %s "${OS_ID_LIKE}" | grep -qi debian; then
        warn "Not officially supported: Trying as Debian-like. (Attempting to proceed)"; install_deps_ubuntu || true
      else
        warn "Unsupported distribution. Skipping dependency installation."
      fi
      ;;
  esac
}

# ==========================
# 7) Generate Wrapper
# ==========================
wrapper_path() { echo "${BIN_DIR}/${APP_CLI_NAME}"; }

install_wrapper() {
  if [ ! -f "${APP_MAIN}" ]; then
    warn "main.py not found: ${APP_MAIN} (Place it later → re-run to update)"
  fi

  log "Generating startup wrapper: $(wrapper_path)"
  mkdir -p "${BIN_DIR}"

  cat >"$(wrapper_path)" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Launches the main GUI file (main.py in repo root) with user privileges
PYTHON="${PYTHON:-python3}"
APP_MAIN="__APP_MAIN__"

exec "${PYTHON}" "${APP_MAIN}" "$@"
EOF

  sed -i "s|__APP_MAIN__|${APP_MAIN}|g" "$(wrapper_path)"
  chmod 0755 "$(wrapper_path)"
}

# ==========================
# 8) Register .desktop (Icon name is without extension)
# ==========================
install_desktop() {
  log "Registering .desktop file: ${DESKTOP_DIR}/${APP_ID}.desktop"
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
# 9) Place Icons (Copy PNG+SVG entirely to hicolor)
# ==========================
install_icons() {
  if [ ! -d "${ICON_SRC_DIR}" ]; then
    warn "Icon source not found (${ICON_SRC_DIR}). Skipping."
    return 0
  fi

  # Simple & reliable: copy the prepared hicolor structure as is
  log "Batch copying icons to hicolor: ${ICON_SRC_DIR} -> ${ICON_DIR}"
  mkdir -p "${ICON_DIR}"
  cp -a "${ICON_SRC_DIR}/." "${ICON_DIR}/"
}

# ==========================
# 10) Update Caches
# ==========================
update_caches() {
  if exists update-desktop-database; then
    log "Updating desktop file database (update-desktop-database)..."
    update-desktop-database "${SHARE_DIR}/applications" || true
  fi
  if exists gtk-update-icon-cache; then
    log "Updating icon cache (gtk-update-icon-cache)..."
    gtk-update-icon-cache -q -t -f "${SHARE_DIR}/icons/hicolor" || true
  fi
}

# ==========================
# 11) Uninstall (Explicitly remove PNG + SVG)
# ==========================
uninstall_all() {
  log "Running uninstallation..."

  # .desktop and wrapper
  rm -f "${DESKTOP_DIR}/${APP_ID}.desktop" || true
  rm -f "$(wrapper_path)" || true

  # PNG and SVG (explicitly by pattern)
  rm -f "${ICON_DIR}/*/apps/${APP_ID}.png" 2>/dev/null || true
  rm -f "${ICON_DIR}/scalable/apps/${APP_ID}.svg" 2>/dev/null || true

  update_caches
  log "Uninstallation complete."
}

# ==========================
# 12) Main Process
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

== Setup Complete ==
Launch Command : ${APP_CLI_NAME}
.desktop File  : ${DESKTOP_DIR}/${APP_ID}.desktop
Icons          : ${ICON_DIR}/...

* The wrapper launches ${APP_MAIN} with user privileges.
* Please use pkexec (polkit) for any root-requiring processes within the GUI (e.g., executing cl_main.py).
* If the repository location changes, re-run this script in the same location to update (overwrite).

To Uninstall:
  sudo $(basename "$0") --uninstall

EOF
}

main "$@"