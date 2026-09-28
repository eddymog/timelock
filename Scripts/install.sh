#!/bin/sh

set -eu

[ "$(/usr/bin/id -u)" -eq 0 ] || {
    echo "Run this installer with sudo." >&2
    exit 1
}

install_user=${SUDO_USER:-}
[ -n "$install_user" ] && [ "$install_user" != "root" ] || {
    echo "SUDO_USER is missing; run sudo ./Scripts/install.sh from your user account." >&2
    exit 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE="$SCRIPT_DIR/timelock-hosts"
DESTINATION=/usr/local/bin/timelock-hosts
SUDOERS_DESTINATION=/etc/sudoers.d/timelock
SUDOERS_TEMP=$(/usr/bin/mktemp /tmp/timelock-sudoers.XXXXXX)
trap '/bin/rm -f "$SUDOERS_TEMP"' EXIT HUP INT TERM

/usr/bin/install -d -o root -g wheel -m 755 /usr/local/bin
/usr/bin/install -o root -g wheel -m 755 "$SOURCE" "$DESTINATION"
printf '%s ALL=(root) NOPASSWD: %s\n' "$install_user" "$DESTINATION" > "$SUDOERS_TEMP"
/bin/chmod 0440 "$SUDOERS_TEMP"
/usr/sbin/visudo -cf "$SUDOERS_TEMP"
/usr/bin/install -o root -g wheel -m 0440 "$SUDOERS_TEMP" "$SUDOERS_DESTINATION"

echo "Timelock website blocking installed for $install_user."
