#!/bin/bash
set -e

source /tmp/env.sh

SCRIPT_NAME="$(basename "$0")"
echo "[$SCRIPT_NAME] Starting locale and timezone setup..."


# Remove extraneous whitespace (to prevent "Bad entry" issues)
LOCALE="$(echo "$LOCALE" | xargs)"

echo "[$SCRIPT_NAME] LOCALE=$LOCALE TIMEZONE=$TIMEZONE"

# Append to locale.gen (prevent duplication)
# The substitution replaces dots with escaped dots for sed pattern matching.
sed -i "/^#\?\s*${LOCALE//./\\.}\s*$/d" /etc/locale.gen
echo "$LOCALE UTF-8" >> /etc/locale.gen

# Generate locales and apply as system default
locale-gen
update-locale LANG="$LOCALE"

# Generate LANGUAGE from LOCALE
# Example: ja_JP.UTF-8 → ja_JP:ja
LANG_CODE="${LOCALE%%.*}"   # ja_JP
BASE_LANG="${LANG_CODE%%_*}" # ja
LANGUAGE_VALUE="${LANG_CODE}:${BASE_LANG}"

# Explicitly set in /etc/default/locale (referenced by GUI)
cat >/etc/default/locale <<EOF
LANG=$LOCALE
LANGUAGE=$LANGUAGE_VALUE
LC_CTYPE=$LOCALE
LC_ALL=
EOF

# Timezone (non-interactive)
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone

echo "[$SCRIPT_NAME] Locale and timezone setup complete"