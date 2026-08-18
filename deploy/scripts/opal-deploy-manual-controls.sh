#!/bin/sh
set -eu

stamp=${1:-$(date +%Y%m%d-%H%M%S)}
backup="/root/d810-deploy-backups/${stamp}-before-manual-controls"

lua -e 'assert(loadfile("/tmp/d810bridge.lua.new"))'
/bin/sh -n /tmp/action-v21.new

mkdir -p "$backup"
cp /www/cgi-bin/d810bridge.lua "$backup/"
cp /www/cgi-bin/action-v21 "$backup/"

cp /tmp/d810bridge.lua.new /www/cgi-bin/d810bridge.lua
cp /tmp/action-v21.new /www/cgi-bin/action-v21
chmod 755 /www/cgi-bin/action-v21

kill "$(cat /tmp/d810-bridge-v21.pid 2>/dev/null)" 2>/dev/null || true
for process_dir in /proc/[0-9]*; do
  command_line=$(cat "$process_dir/cmdline" 2>/dev/null | tr '\000' ' ' || true)
  case "$command_line" in
    *'/www/cgi-bin/d810bridge.lua daemon'*)
      kill "${process_dir##*/}" 2>/dev/null || true
      ;;
  esac
done
sleep 1
/www/cgi-bin/session-manager

printf 'DEPLOY_OK backup=%s\n' "$backup"
