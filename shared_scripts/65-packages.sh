#!/bin/bash
set -e

echo "[65-packages.sh] Installing packages (Flatpak included)..."

source /etc/os-release


# Add Universe and Multiverse repositories (explicitly added as Ubuntu Noble uses a minimal setup)
echo "[INFO] Adding universe/multiverse repositories to sources.list"
cat <<EOF > /etc/apt/sources.list

deb http://ftp.riken.go.jp/Linux/ubuntu $VERSION_CODENAME main restricted universe multiverse
deb http://ftp.riken.go.jp/Linux/ubuntu $VERSION_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $VERSION_CODENAME-security main restricted universe multiverse
EOF

# Update the package list
apt update

# Install regular packages
if [ -n "$PACKAGE_LIST" ]; then
    IFS="," read -r -a __PKGS <<< "$PACKAGE_LIST"
    echo "[INFO] Installing regular packages: ${__PKGS[*]}"
    apt install -y "${__PKGS[@]}"
fi

# Upgrade installed packages
apt upgrade -y

# Install Flatpak if not already installed
if ! command -v flatpak > /dev/null; then
    echo "[INFO] Could not find the Flatpak installation. Installing..."
    apt install -y flatpak || {
        echo "[ERROR] Failed to install flatpak"
        exit 1
    }
fi

# Set setuid bit for bwrap
# This line sets the setuid bit for the 'bwrap' executable, often required for unprivileged Flatpak usage.
chmod u+s $(which bwrap)


# Register Flathub
if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install Flatpak apps
if [ -n "$FLATPAK_LIST" ]; then
    echo "[INFO] Installing Flatpak apps: $FLATPAK_LIST"
    IFS="," read -r -a __FLATS <<< "$FLATPAK_LIST"
    for app in "${__FLATS[@]}"; do
        flatpak install -y flathub "$app"
       ## Avoids garbled characters (Japanese comment in original)
        #flatpak run --command=fc-cache $app -f -v 

    done

    # Set fcitx5 environment variables for Flatpak apps
    echo "[65-packages.sh] Setting fcitx5 environment variables for Flatpak..."
    flatpak override --system \
        --env=GTK_IM_MODULE=fcitx \
        --env=QT_IM_MODULE=fcitx \
        --env=XMODIFIERS=@im=fcitx \
        --env=INPUT_METHOD=fcitx

fi
