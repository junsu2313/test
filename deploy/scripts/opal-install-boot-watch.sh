#!/bin/sh

set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
STAGED=${1:-/tmp/d810-boot-watch.singleton}
STAGED_INIT=${2:-/tmp/d810-boot-watch.init}
TARGET=/usr/bin/d810-boot-watch
INIT_TARGET=/etc/init.d/d810-boot-watch
BACKUP_ROOT=${D810_SCRIPT_BACKUP_ROOT:-/root/d810-script-backups}
LOCK_DIR=${D810_WATCH_LOCK:-/tmp/d810-boot-watch.lock}

[ -f "$STAGED" ] || { printf 'staged watcher missing\n' >&2; exit 2; }
[ -f "$STAGED_INIT" ] || { printf 'staged init script missing\n' >&2; exit 2; }
/bin/sh -n "$STAGED"
/bin/sh -n "$STAGED_INIT"
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_ROOT"
[ -f "$TARGET" ] && cp "$TARGET" "$BACKUP_ROOT/$stamp-boot-watch"
[ -f "$INIT_TARGET" ] && cp "$INIT_TARGET" "$BACKUP_ROOT/$stamp-boot-watch.init"

/etc/init.d/d810-boot-watch stop >/dev/null 2>&1 || true
pids=$(ps w | awk '$5=="/bin/sh" && $6=="/usr/bin/d810-boot-watch" {print $1}')
for pid in $pids; do
  kill "$pid" 2>/dev/null || true
done

attempt=1
while [ "$attempt" -le 10 ]; do
  remaining=$(ps w | awk '$5=="/bin/sh" && $6=="/usr/bin/d810-boot-watch" {print $1}')
  [ -z "$remaining" ] && break
  sleep 1
  attempt=$((attempt + 1))
done
[ -z "${remaining:-}" ] || { printf 'old watchers still running: %s\n' "$remaining" >&2; exit 3; }

rm -f "$LOCK_DIR/pid"
rmdir "$LOCK_DIR" 2>/dev/null || true
mv "$STAGED" "$TARGET"
mv "$STAGED_INIT" "$INIT_TARGET"
chmod 755 "$TARGET"
chmod 755 "$INIT_TARGET"
"$INIT_TARGET" enable
"$INIT_TARGET" start
sleep 2
count=$(ps w | awk '$5=="/bin/sh" && $6=="/usr/bin/d810-boot-watch" {count++} END {print count+0}')
[ "$count" -eq 1 ] || { printf 'unexpected watcher count: %s\n' "$count" >&2; exit 4; }
[ -L /etc/rc.d/S96d810-boot-watch ] || { printf 'watcher is not enabled at boot\n' >&2; exit 5; }
sync
printf 'WATCHERS=%s ENABLED=1 BACKUP=%s/%s-boot-watch\n' "$count" "$BACKUP_ROOT" "$stamp"
