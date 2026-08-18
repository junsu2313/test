#!/bin/sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin
RUN_ROOT=${D810_FIELD_RUN_ROOT:-/root/d810-field-runs}
S10_IP=${D810_FIELD_S10_IP:-192.168.8.165}
INTERVAL=${D810_FIELD_INTERVAL_SEC:-2}
OUTBOX=${D810_FIELD_OUTBOX_ENQUEUE:-/usr/bin/opal-outbox-enqueue}

RUN_ID=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RUN_ROOT/$RUN_ID"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/observer.jsonl"
printf '%s\n' "$RUN_ID" > "$RUN_ROOT/latest"

now() { date '+%Y-%m-%dT%H:%M:%S%z'; }
uptime_s() { awk '{print $1}' /proc/uptime; }
s10_state() {
  ping -c 1 -W 1 "$S10_IP" >/dev/null 2>&1 && printf connected || printf unreachable
}
app_peer() {
  netstat -tn 2>/dev/null | awk '$4 ~ /:8191$/ && $6 == "ESTABLISHED" {print $5; exit}'
}
network_interface() {
  ip route get "$S10_IP" 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}
network_counter() {
  interface=$1
  counter=$2
  [ -n "$interface" ] && cat "/sys/class/net/$interface/statistics/$counter" 2>/dev/null || printf 0
}
camera_usb_state() {
  for vendor_file in /sys/bus/usb/devices/*/idVendor; do
    [ -r "$vendor_file" ] || continue
    [ "$(cat "$vendor_file" 2>/dev/null)" = "04b0" ] && { printf connected; return; }
  done
  printf missing
}
thermal_millic() {
  for thermal_file in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$thermal_file" ] || continue
    cat "$thermal_file" 2>/dev/null
    return
  done
  printf 0
}
process_count() {
  ps w 2>/dev/null | grep -E 'ddserver|d810bridge.lua|d810ws.lua|runtime-guardian|battery-worker' | grep -v grep | wc -l
}
status_json() {
  wget -qO- --timeout=2 http://127.0.0.1/cgi-bin/status-v21 2>/dev/null || printf '{}'
}

printf '{"wall":"%s","uptime_s":"%s","event":"field_observer_started","run":"%s","s10":"%s"}\n' \
  "$(now)" "$(uptime_s)" "$RUN_ID" "$S10_IP" >> "$LOG"
cleanup() {
  printf '{"wall":"%s","uptime_s":"%s","event":"field_observer_stopped","run":"%s"}\n' \
    "$(now)" "$(uptime_s)" "$RUN_ID" >> "$LOG"
  "$OUTBOX" "$LOG" field-observer >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

while :; do
  status=$(status_json)
  s10=$(s10_state)
  peer=$(app_peer)
  interface=$(network_interface)
  rx_bytes=$(network_counter "$interface" rx_bytes)
  tx_bytes=$(network_counter "$interface" tx_bytes)
  usb=$(camera_usb_state)
  thermal=$(thermal_millic)
  processes=$(process_count)
  available=$(df -k / | awk 'NR==2 {print $4; exit}')
  memory=$(awk '$1=="MemAvailable:" {print $2; exit}' /proc/meminfo)
  load1=$(awk '{print $1}' /proc/loadavg)
  printf '{"wall":"%s","uptime_s":"%s","event":"field_observation","run":"%s","s10":"%s","appPeer":"%s","networkInterface":"%s","rxBytes":%s,"txBytes":%s,"cameraUsb":"%s","processCount":%s,"availableKb":%s,"memAvailableKb":%s,"thermalMilliC":%s,"load1":%s,"status":%s}\n' \
    "$(now)" "$(uptime_s)" "$RUN_ID" "$s10" "${peer:-}" "${interface:-}" \
    "${rx_bytes:-0}" "${tx_bytes:-0}" "$usb" "${processes:-0}" "${available:-0}" \
    "${memory:-0}" "${thermal:-0}" "${load1:-0}" "$status" >> "$LOG"
  sleep "$INTERVAL"
done
