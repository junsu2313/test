#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
CGI_DIR=${D810_CGI_DIR:-/www/cgi-bin}
BACKUP_ROOT=${D810_SCRIPT_BACKUP_ROOT:-/root/d810-script-backups}

/bin/sh -n /tmp/action-v21.trace
/bin/sh -n /tmp/bridge-common.sh.trace
/usr/bin/lua -e "assert(loadfile('/tmp/d810bridge.lua.trace'))"

stamp=$(date +%Y%m%d-%H%M%S)
backup="$BACKUP_ROOT/$stamp-trace"
mkdir -p "$backup"
cp "$CGI_DIR/action-v21" "$CGI_DIR/bridge-common.sh" "$CGI_DIR/d810bridge.lua" "$backup/"

mv /tmp/action-v21.trace "$CGI_DIR/action-v21"
mv /tmp/bridge-common.sh.trace "$CGI_DIR/bridge-common.sh"
mv /tmp/d810bridge.lua.trace "$CGI_DIR/d810bridge.lua"
chmod 755 "$CGI_DIR/action-v21" "$CGI_DIR/bridge-common.sh"

QUERY_STRING= /bin/sh "$CGI_DIR/session-manager" > /tmp/trace-session-restart.out
cat /tmp/trace-session-restart.out
printf 'BACKUP=%s\n' "$backup"

