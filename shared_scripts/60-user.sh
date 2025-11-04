#!/bin/bash

set -e

# Read username, password, and groups
USERNAME="${USERNAME:-livermorium}"
PASSWORD="${PASSWORD:-livermorium}"
USER_GROUPS="${USER_GROUPS:-wheel}"

echo "[INFO] Creating user '$USERNAME'..."
echo "[INFO] Setting new user's groups...: $USER_GROUPS"

# Create groups if they don't exist
IFS="," read -r -a __GRPS <<< "$USER_GROUPS"
for group in "${__GRPS[@]}"; do
    if ! getent group "$group" > /dev/null 2>&1; then
        echo "[INFO] Creating unexisting group: '$group'"
        groupadd "$group"
    fi
done

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    echo "[WARN] User '$USERNAME' already exists"
else
    # Create the user
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "[INFO] User '$USERNAME' created"
fi

# Add the user to the groups
IFS="," read -r -a __GRPS <<< "$USER_GROUPS"
for group in "${__GRPS[@]}"; do
    usermod -aG "$group" "$USERNAME"
done

echo "[INFO] Added '$USERNAME' to groups '$USER_GROUPS'"