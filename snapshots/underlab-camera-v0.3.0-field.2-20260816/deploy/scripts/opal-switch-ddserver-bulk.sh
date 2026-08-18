#!/bin/sh
set -eu

SIZE="${1:-512}"
case "$SIZE" in
  512|4096|16384|32768|65536) ;;
  *)
    echo "unsupported bulk size: $SIZE" >&2
    exit 2
    ;;
esac

{
  echo "DDSERVER_BULK_READ_SIZE=$SIZE"
  echo "DDSERVER_TRACE_USB=1"
} > /etc/d810-ddserver.env

kill "$(cat /tmp/d810-bridge-v21.pid 2>/dev/null)" 2>/dev/null || true
kill "$(cat /tmp/d810-ws-v21.pid 2>/dev/null)" 2>/dev/null || true
for process_dir in /proc/[0-9]*; do
  command_line=$(cat "$process_dir/cmdline" 2>/dev/null | tr '\000' ' ' || true)
  case "$command_line" in
    *'/www/cgi-bin/d810bridge.lua daemon'*)
      kill "${process_dir##*/}" 2>/dev/null || true
      ;;
  esac
done

ubus call service delete '{"name":"ddserver"}' >/dev/null 2>&1 || true
for PID in $(pidof ddserver 2>/dev/null); do
  kill -9 "$PID" 2>/dev/null || true
done
sleep 1

DDSERVER_BULK_READ_SIZE="$SIZE" DDSERVER_TRACE_USB=1 \
  /usr/bin/ddserver >/tmp/ddserver-v5-"$SIZE".log 2>&1 &
echo "$!" > /tmp/ddserver-v5-manual.pid
sleep 2

/www/cgi-bin/session-manager
