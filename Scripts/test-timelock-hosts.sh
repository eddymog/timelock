#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPT="$SCRIPT_DIR/timelock-hosts"
TEST_DIR=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/timelock-hosts-tests.XXXXXX")
HOSTS="$TEST_DIR/hosts"
ORIGINAL="$TEST_DIR/original"
trap '/bin/rm -rf "$TEST_DIR"' EXIT HUP INT TERM

printf '127.0.0.1 localhost\n255.255.255.255 broadcasthost\n' > "$ORIGINAL"
/bin/cp "$ORIGINAL" "$HOSTS"
[ "$(HOSTS_FILE="$HOSTS" "$SCRIPT" status)" = "inactive" ]

HOSTS_FILE="$HOSTS" "$SCRIPT" block youtube.com www.youtube.com
[ "$(HOSTS_FILE="$HOSTS" "$SCRIPT" status)" = "active" ]
/usr/bin/grep -Fqx '# >>> Timelock BEGIN' "$HOSTS"
/usr/bin/grep -Fqx '0.0.0.0 youtube.com' "$HOSTS"
/usr/bin/grep -Fqx ':: www.youtube.com' "$HOSTS"

HOSTS_FILE="$HOSTS" "$SCRIPT" block youtube.com www.youtube.com
[ "$(/usr/bin/grep -Fc '# >>> Timelock BEGIN' "$HOSTS")" -eq 1 ]

HOSTS_FILE="$HOSTS" "$SCRIPT" unblock
[ "$(HOSTS_FILE="$HOSTS" "$SCRIPT" status)" = "inactive" ]
/usr/bin/cmp -s "$ORIGINAL" "$HOSTS"

for invalid in 'a b' 'x;rm' ''; do
    /bin/cp "$ORIGINAL" "$HOSTS"
    if HOSTS_FILE="$HOSTS" "$SCRIPT" block "$invalid" 2>/dev/null; then
        echo "invalid domain was accepted: $invalid" >&2
        exit 1
    fi
    /usr/bin/cmp -s "$ORIGINAL" "$HOSTS"
done

echo "timelock-hosts tests passed"
