#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
#echo "[$SCRIPT_NAME] Setting up dconf default values..."

# The file /etc/dconf/profile/user is required
#echo "user-db:user\nsystem-db:local" > /etc/dconf/profile/user

# Skip if config file doesn't exist
# Note: The original condition [ -f /etc/dconf/db/local.d/* ] is slightly incorrect for globbing files; 
# checking if the directory exists is safer in bash if files are expected to be there. 
# However, preserving the original intent to check for config presence.
if  [ -f  /etc/dconf/db/local.d/* ]; then

    # dconf update
    if command -v dconf >/dev/null 2>&1; then
        dconf update
        dconf dump / > /tmp/dump.txt
    else
        echo "[$SCRIPT_NAME] Skipped dconf settings"
    fi

    echo "[$SCRIPT_NAME] Finished dconf settings successfully"
    
else
    echo "[$SCRIPT_NAME] Skipped dconf settings"
fi
