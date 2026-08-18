#!/bin/sh

COUNT=${1:-10}
CLIENT_IP=${D810_TEST_CLIENT_IP:-192.168.8.250}
S10_IP=${D810_TEST_S10_IP:-192.168.8.165}
S10_PROBE_ATTEMPTS=${D810_TEST_S10_PROBE_ATTEMPTS:-3}
S10_REQUIRED=${D810_TEST_S10_REQUIRED:-0}
RUN_ROOT=${D810_TEST_RUN_ROOT:-/root/d810-test-runs}
CLIENT=${D810_TEST_CLIENT:-/usr/bin/d810-virtual-camera-client}
CLIENT_MODE=${D810_TEST_CLIENT_MODE:-virtual}
OUTBOX_ENQUEUE=${D810_TEST_OUTBOX_ENQUEUE:-/usr/bin/opal-outbox-enqueue}
OUTBOX_ENABLED=${D810_TEST_OUTBOX_ENABLED:-1}
D810_TEST_BATTERY_MIN_PERCENT=${D810_TEST_BATTERY_MIN_PERCENT:-20}
BATTERY_QUERY_INTERVAL_SEC=${D810_TEST_BATTERY_QUERY_INTERVAL_SEC:-600}
STORAGE_MIN_KB=${D810_TEST_STORAGE_MIN_KB:-5120}
RUNNER_VERSION=serial-observer-v3-timing
BATTERY_MAX_QUERY_FAILURES=${D810_TEST_BATTERY_MAX_QUERY_FAILURES:-2}
LOCK=/tmp/d810-camera-loop.lock
CGI_DIR=/www/cgi-bin

case "$COUNT" in
  ''|*[!0-9]*) printf 'invalid loop count\n' >&2; exit 2 ;;
esac
[ "$COUNT" -gt 0 ] || exit 2

SCRIPT_DIR=$CGI_DIR
. "$CGI_DIR/variant-v21-env.sh"
SCRIPT_DIR=$CGI_DIR
. "$CGI_DIR/bridge-common.sh"

mkdir "$LOCK" 2>/dev/null || { printf 'test loop already active\n' >&2; exit 3; }
RUN_ID=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RUN_ROOT/$RUN_ID"
mkdir -p "$RUN_DIR"
EXTERNAL_GATE_DIR="$RUN_DIR/external-client"
mkdir -p "$EXTERNAL_GATE_DIR"
printf '%s\n' "$RUN_ID" > "$RUN_ROOT/latest"
SESSION_STATE_SNAPSHOT="$RUN_DIR/session-v21.state"

timeline() {
  event=$1
  detail=${2:-}
  log="/root/d810-watch-logs/timeline-$(date +%Y%m%d).jsonl"
  mkdir -p "$(dirname "$log")"
  read -r uptime_value _ < /proc/uptime
  printf '{"wall":"%s","uptime_s":"%s","event":"%s","run":"%s"%s}\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$uptime_value" "$event" "$RUN_ID" "$detail" >> "$log"
}

nikon_device() {
  for vendor_file in /sys/bus/usb/devices/*/idVendor; do
    [ -r "$vendor_file" ] || continue
    if [ "$(cat "$vendor_file" 2>/dev/null)" = "04b0" ]; then
      basename "$(dirname "$vendor_file")"
      return 0
    fi
  done
  return 1
}

s10_reachable() {
  attempt=1
  while [ "$attempt" -le "$S10_PROBE_ATTEMPTS" ]; do
    ping -c 1 -W 1 "$S10_IP" >/dev/null 2>&1 && return 0
    sleep 1
    attempt=$((attempt + 1))
  done
  return 1
}

storage_available_kb() {
  df -k / | awk 'NR==2 {print $4; exit}'
}

enqueue_artifact() {
  source=$1
  category=${2:-test}
  [ "$OUTBOX_ENABLED" = "1" ] || return 0
  [ -x "$OUTBOX_ENQUEUE" ] || return 1
  [ -f "$source" ] || return 1
  "$OUTBOX_ENQUEUE" "$source" "$category" >/dev/null 2>&1
}

run_client_action() {
  output_dir=$1
  if [ "$CLIENT_MODE" = "s10" ]; then
    ready_file="$EXTERNAL_GATE_DIR/loop-$loop.ready"
    result_file="$EXTERNAL_GATE_DIR/loop-$loop.result"
    rm -f "$ready_file" "$result_file"
    printf '%s\n' "$loop" > "$ready_file"
    timeline external_client_ready ",\"loop\":$loop"
    while [ ! -f "$result_file" ]; do
      [ -f "$RUN_DIR/stop" ] && return 1
      sleep 1
    done
    result=$(cat "$result_file" 2>/dev/null || true)
    [ "$result" = "PASS" ]
    return $?
  fi
  "$CLIENT" "$output_dir"
}

stack_snapshot() {
  output=$1
  ps w | grep -E 'ddserver|d810bridge|d810ws|frame-refresh|runtime-guardian|stack-guardian|session-health|battery-worker' \
    | grep -v grep > "$output" 2>/dev/null || true
}

project_pids() {
  ps w | while read -r pid user vsz stat command; do
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    case "$command" in
      *'/www/cgi-bin/d810bridge.lua'*|*'/www/cgi-bin/d810ws.lua'*|*'/www/cgi-bin/frame-refresh-v21'*|\
      *'/www/cgi-bin/runtime-guardian'*|*'/www/cgi-bin/stack-guardian'*|*'/www/cgi-bin/session-health'*|\
      *'/www/cgi-bin/battery-worker'*|*'/www/cgi-bin/session-manager'*|*'/www/cgi-bin/action-v21'*) printf '%s\n' "$pid" ;;
    esac
  done
}

stop_stack() {
  /bin/sh "$CGI_DIR/frame-refresh-v21" stop >/dev/null 2>&1 || true
  ws_stop >/dev/null 2>&1 || true
  battery_worker_stop >/dev/null 2>&1 || true
  session_health_stop >/dev/null 2>&1 || true
  stack_guardian_stop >/dev/null 2>&1 || true
  runtime_guardian_stop >/dev/null 2>&1 || true
  # Release the Nikon PTP session before killing ddserver.  USB authorization
  # cycling does not clear a camera-side session that was left open, and the
  # next OpenSession can then hang until a later command gets 0x201E.
  bridge_request_timed STOP 8 >/dev/null 2>&1 || true
  bridge_stop >/dev/null 2>&1 || true
  /etc/init.d/ddserver stop >/dev/null 2>&1 || true
  killall -q ddserver 2>/dev/null || true
  /etc/init.d/nginx stop >/dev/null 2>&1 || true
  for pid in $(project_pids); do kill "$pid" 2>/dev/null || true; done
  sleep 1
  for pid in $(project_pids); do kill -KILL "$pid" 2>/dev/null || true; done
  attempt=1
  while [ "$attempt" -le 10 ]; do
    [ -z "$(project_pids)" ] && ! pidof ddserver >/dev/null 2>&1 && ! pidof nginx >/dev/null 2>&1 && break
    sleep 1
    attempt=$((attempt + 1))
  done
  purge_runtime_tmp
}

stack_is_down() {
  ! pidof ddserver >/dev/null 2>&1 && \
    ! pidof nginx >/dev/null 2>&1 && \
    [ -z "$(project_pids)" ]
}

cycle_camera_usb() {
  device=$(nikon_device 2>/dev/null || true)
  [ -n "$device" ] || return 1
  authorized="/sys/bus/usb/devices/$device/authorized"
  [ -w "$authorized" ] || return 2
  printf '0\n' > "$authorized"
  sleep 2
  printf '1\n' > "$authorized"
  attempt=1
  while [ "$attempt" -le 15 ]; do
    nikon_device >/dev/null 2>&1 && return 0
    sleep 1
    attempt=$((attempt + 1))
  done
  return 3
}

start_stack() {
  boot_stage() {
    stage=$1
    start_ms=$2
    end_ms=$(now_ms)
    timing "$loop" "boot_$stage" "$start_ms" "$end_ms" PASS
    timeline "boot_$stage" ",\"loop\":$loop,\"durationMs\":$((end_ms - start_ms))"
  }
  stage_start=$(now_ms)
  timeline boot_nginx_start ",\"loop\":$loop"
  /etc/init.d/nginx start >/dev/null 2>&1 || return 1
  attempt=1
  while [ "$attempt" -le 10 ]; do
    pidof nginx >/dev/null 2>&1 && break
    sleep 1
    attempt=$((attempt + 1))
  done
  pidof nginx >/dev/null 2>&1 || return 1
  boot_stage nginx_ready "$stage_start"
  stage_start=$(now_ms)
  timeline boot_ddserver_start ",\"loop\":$loop"
  /etc/init.d/ddserver start >/dev/null 2>&1 || return 1
  attempt=1
  while [ "$attempt" -le 10 ]; do
    pidof ddserver >/dev/null 2>&1 && break
    sleep 1
    attempt=$((attempt + 1))
  done
  pidof ddserver >/dev/null 2>&1 || return 1
  boot_stage ddserver_ready "$stage_start"
  if [ -s "$SESSION_STATE_SNAPSHOT" ]; then
    cp "$SESSION_STATE_SNAPSHOT" /tmp/d810-session-v21.state
  fi
  manager_log=${1:-/tmp/d810-test-session-manager.$$.out}
  stage_start=$(now_ms)
  timeline boot_session_manager_start ",\"loop\":$loop"
  QUERY_STRING= /bin/sh "$CGI_DIR/session-manager" > "$manager_log" 2>&1
  cat "$manager_log"
  if grep -F '"ok":true' "$manager_log" >/dev/null 2>&1; then
    boot_stage session_manager_ready "$stage_start"
    return 0
  fi
  return 1
}

cleanup() {
  ip addr del "$CLIENT_IP/32" dev lo 2>/dev/null || true
  rmdir "$LOCK" 2>/dev/null || true
  pidof nginx >/dev/null 2>&1 || /etc/init.d/nginx start >/dev/null 2>&1 || true
  pidof ddserver >/dev/null 2>&1 || /etc/init.d/ddserver start >/dev/null 2>&1 || true
  if [ -s "$SESSION_STATE_SNAPSHOT" ]; then
    cp "$SESSION_STATE_SNAPSHOT" /tmp/d810-session-v21.state
  fi
  if ! bridge_alive >/dev/null 2>&1; then
    timeout -t 90 sh -c 'QUERY_STRING= /bin/sh "$1"' sh "$CGI_DIR/session-manager" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 143' INT TERM

if ! command -v curl >/dev/null 2>&1 || \
   ! command -v timeout >/dev/null 2>&1 || \
   ! command -v hexdump >/dev/null 2>&1 || \
   ! command -v lua >/dev/null 2>&1; then
  printf 'required client tools unavailable\n' > "$RUN_DIR/preflight-error.txt"
  timeline test_run_aborted ',"reason":"client_tools_unavailable"'
  exit 4
fi
if ! nikon_device >/dev/null 2>&1; then
  printf 'Nikon USB device not connected\n' > "$RUN_DIR/preflight-error.txt"
  timeline test_run_aborted ',"reason":"nikon_usb_missing"'
  exit 5
fi
if ! s10_reachable; then
  printf 'S10 is not reachable at %s\n' "$S10_IP" > "$RUN_DIR/preflight-error.txt"
  timeline s10_unreachable ',"phase":"preflight","s10Ip":"'"$S10_IP"'"'
  [ "$S10_REQUIRED" = "1" ] && exit 7
fi

ip addr add "$CLIENT_IP/32" dev lo 2>/dev/null || true
ip addr show dev lo | grep -F "$CLIENT_IP/32" >/dev/null 2>&1 || {
  timeline test_run_aborted ',"reason":"client_ip_failed"'
  exit 6
}

 timeline test_run_started ",\"loops\":$COUNT,\"clientIp\":\"$CLIENT_IP\",\"runner\":\"$RUNNER_VERSION\""
printf 'loop\tresult\tsession\n' > "$RUN_DIR/summary.tsv"
printf 'loop\tsegment\tstart_ms\tend_ms\tduration_ms\tresult\n' > "$RUN_DIR/timings.tsv"
printf 'loop\tuptime_s\tbattery_percent\tthreshold\tsource\n' > "$RUN_DIR/battery.tsv"
printf 'loop\tphase\tip\tresult\tuptime_s\n' > "$RUN_DIR/s10.tsv"
printf 'loop\tavailable_kb\tminimum_kb\tresult\n' > "$RUN_DIR/storage.tsv"

timing() {
  loop_id=$1
  segment=$2
  start_ms=$3
  end_ms=$4
  result=$5
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$loop_id" "$segment" "$start_ms" "$end_ms" "$((end_ms - start_ms))" "$result" \
    >> "$RUN_DIR/timings.tsv"
  if [ -n "${LOOP_TIMINGS_FILE:-}" ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$loop_id" "$segment" "$start_ms" "$end_ms" "$((end_ms - start_ms))" "$result" \
      >> "$LOOP_TIMINGS_FILE"
  fi
}

record_battery() {
  loop_id=$1
  battery_value=$2
  source=$3
  read -r uptime_value _ < /proc/uptime
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$loop_id" "$uptime_value" "${battery_value:-unknown}" \
    "$D810_TEST_BATTERY_MIN_PERCENT" "$source" >> "$RUN_DIR/battery.tsv"
  if [ -n "${LOOP_BATTERY_FILE:-}" ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$loop_id" "$uptime_value" "${battery_value:-unknown}" \
      "$D810_TEST_BATTERY_MIN_PERCENT" "$source" >> "$LOOP_BATTERY_FILE"
  fi
}

read_battery_now() {
  output=$(curl --connect-timeout 3 --max-time 8 -sS \
    http://127.0.0.1/cgi-bin/status-v21?battery_probe=$(date +%s) 2>/dev/null || true)
  value=$(printf '%s\n' "$output" | grep -Eo '"batteryPercent":[0-9]+' | head -n 1 | tr -cd '0-9')
  case "$value" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$value"
}

loop=1
battery_query_failures=0
last_battery_query_uptime=0
while [ "$loop" -le "$COUNT" ]; do
  LOOP_DIR="$RUN_DIR/loop-$(printf '%02d' "$loop")"
  mkdir -p "$LOOP_DIR"
  LOOP_TIMINGS_FILE="$LOOP_DIR/timings.tsv"
  LOOP_BATTERY_FILE="$LOOP_DIR/battery.tsv"
  printf 'loop\tsegment\tstart_ms\tend_ms\tduration_ms\tresult\n' > "$LOOP_TIMINGS_FILE"
  printf 'loop\tuptime_s\tbattery_percent\tthreshold\tsource\n' > "$LOOP_BATTERY_FILE"
  loop_start_ms=$(now_ms)
  if [ -n "${last_battery_percent:-}" ] && [ "$last_battery_percent" -le "$D810_TEST_BATTERY_MIN_PERCENT" ]; then
    record_battery "$loop" "$last_battery_percent" previous_loop_guard
    printf '%s\tSTOPPED_BATTERY\t%s\n' "$loop" "${session:-0}" >> "$RUN_DIR/summary.tsv"
     timeline test_run_stopped ",\"loop\":$loop,\"reason\":\"battery_exhausted\",\"batteryPercent\":$last_battery_percent"
    break
  fi
  timeline test_loop_started ",\"loop\":$loop"
  stack_snapshot "$LOOP_DIR/processes-before.txt"
  segment_start_ms=$(now_ms)
  stop_stack
  segment_end_ms=$(now_ms)
  stack_snapshot "$LOOP_DIR/processes-stopped.txt"
  if ! stack_is_down; then
    timing "$loop" stack_stop "$segment_start_ms" "$segment_end_ms" FAIL
    printf '%s\tFAIL\tstack_not_down\n' "$loop" >> "$RUN_DIR/summary.tsv"
    timeline test_loop_failed ",\"loop\":$loop,\"step\":\"stack_stop\""
    loop=$((loop + 1))
    continue
  fi
  timing "$loop" stack_stop "$segment_start_ms" "$segment_end_ms" PASS
  timeline test_stack_stopped ",\"loop\":$loop"

  segment_start_ms=$(now_ms)
  if ! cycle_camera_usb; then
    segment_end_ms=$(now_ms)
    timing "$loop" usb_cycle "$segment_start_ms" "$segment_end_ms" FAIL
    printf '%s\tFAIL\tusb_cycle_failed\n' "$loop" >> "$RUN_DIR/summary.tsv"
    timeline test_loop_failed ",\"loop\":$loop,\"step\":\"usb_cycle\""
    loop=$((loop + 1))
    continue
  fi
  segment_end_ms=$(now_ms)
  timing "$loop" usb_cycle "$segment_start_ms" "$segment_end_ms" PASS
  timeline test_usb_reconnected ",\"loop\":$loop"

  segment_start_ms=$(now_ms)
  if ! start_stack "$LOOP_DIR/session-manager.out"; then
    segment_end_ms=$(now_ms)
    timing "$loop" serialized_boot "$segment_start_ms" "$segment_end_ms" FAIL
    printf '%s\tFAIL\tstack_start_failed\n' "$loop" >> "$RUN_DIR/summary.tsv"
    timeline test_loop_failed ",\"loop\":$loop,\"step\":\"stack_start\""
    loop=$((loop + 1))
    continue
  fi
  if [ ! -s "$SESSION_STATE_SNAPSHOT" ] && [ -s /tmp/d810-session-v21.state ]; then
    cp /tmp/d810-session-v21.state "$SESSION_STATE_SNAPSHOT"
  fi
  segment_end_ms=$(now_ms)
  timing "$loop" serialized_boot "$segment_start_ms" "$segment_end_ms" PASS
  session=$(sed -n 's/.*"sessionId":\([0-9][0-9]*\).*/\1/p' "$LOOP_DIR/session-manager.out" | tail -n 1)
  if [ -z "$session" ]; then
    session=$(sed -n 's/^sessionId=//p' /tmp/d810-session-v21.state | head -n 1)
  fi
  timeline test_stack_started ",\"loop\":$loop,\"session\":${session:-0}"
  read -r uptime_value _ < /proc/uptime
  uptime_seconds=${uptime_value%%.*}
  battery_percent=${last_battery_percent:-}
  battery_due=1
  if [ "$last_battery_query_uptime" -gt 0 ] && [ $((uptime_seconds - last_battery_query_uptime)) -lt "$BATTERY_QUERY_INTERVAL_SEC" ]; then
    battery_due=0
  fi
  if [ "$battery_due" -eq 1 ]; then
    battery_percent=$(read_battery_now 2>/dev/null || true)
    last_battery_query_uptime=$uptime_seconds
    if [ -n "$battery_percent" ]; then
      battery_query_failures=0
      record_battery "$loop" "$battery_percent" fresh_10m
    else
      battery_query_failures=$((battery_query_failures + 1))
      record_battery "$loop" unknown fresh_10m_failed
    fi
  else
    record_battery "$loop" "${last_battery_percent:-unknown}" not_queried_10m
  fi
  if [ "$battery_due" -eq 1 ] && [ -n "$battery_percent" ] && [ "$battery_percent" -le "$D810_TEST_BATTERY_MIN_PERCENT" ]; then
    printf '%s\tSTOPPED_BATTERY\t%s\n' "$loop" "${session:-0}" >> "$RUN_DIR/summary.tsv"
    timeline test_run_stopped ",\"loop\":$loop,\"reason\":\"battery_exhausted\",\"batteryPercent\":$battery_percent"
    break
  fi
  if [ "$battery_query_failures" -ge "$BATTERY_MAX_QUERY_FAILURES" ]; then
    printf '%s\tSTOPPED_BATTERY_UNKNOWN\t%s\n' "$loop" "${session:-0}" >> "$RUN_DIR/summary.tsv"
    timeline test_run_stopped ",\"loop\":$loop,\"reason\":\"battery_query_failed\",\"queryFailures\":$battery_query_failures"
    break
  fi
  last_battery_percent=$battery_percent

  if s10_reachable; then
    read -r uptime_value _ < /proc/uptime
    printf '%s\tpre_client\t%s\tPASS\t%s\n' "$loop" "$S10_IP" "$uptime_value" >> "$RUN_DIR/s10.tsv"
  else
    read -r uptime_value _ < /proc/uptime
    printf '%s\tpre_client\t%s\tFAIL\t%s\n' "$loop" "$S10_IP" "$uptime_value" >> "$RUN_DIR/s10.tsv"
    timeline s10_unreachable ",\"loop\":$loop,\"phase\":\"pre_client\",\"s10Ip\":\"$S10_IP\""
    if [ "$S10_REQUIRED" = "1" ]; then
      printf '%s\tFAIL\ts10_disconnected\n' "$loop" >> "$RUN_DIR/summary.tsv"
      loop=$((loop + 1))
      continue
    fi
  fi

  available_kb=$(storage_available_kb)
  if [ -z "$available_kb" ] || [ "$available_kb" -lt "$STORAGE_MIN_KB" ]; then
    printf '%s\t%s\t%s\tFAIL\n' "$loop" "${available_kb:-unknown}" "$STORAGE_MIN_KB" >> "$RUN_DIR/storage.tsv"
    printf '%s\tSTOPPED_STORAGE\t%s\n' "$loop" "${session:-0}" >> "$RUN_DIR/summary.tsv"
    timeline test_run_stopped ",\"loop\":$loop,\"reason\":\"storage_low\",\"availableKb\":${available_kb:-0}"
    break
  fi
  printf '%s\t%s\t%s\tPASS\n' "$loop" "$available_kb" "$STORAGE_MIN_KB" >> "$RUN_DIR/storage.tsv"

  segment_start_ms=$(now_ms)
  if run_client_action "$LOOP_DIR/client"; then
    segment_end_ms=$(now_ms)
    timing "$loop" client_actions "$segment_start_ms" "$segment_end_ms" PASS
    result=PASS
    timeline test_loop_passed ",\"loop\":$loop,\"session\":${session:-0}"
  else
    segment_end_ms=$(now_ms)
    timing "$loop" client_actions "$segment_start_ms" "$segment_end_ms" FAIL
    result=FAIL
    timeline test_loop_failed ",\"loop\":$loop,\"step\":\"client\",\"session\":${session:-0}"
  fi
  loop_end_ms=$(now_ms)
  timing "$loop" total "$loop_start_ms" "$loop_end_ms" "$result"
  printf '%s\t%s\t%s\n' "$loop" "$result" "${session:-0}" >> "$RUN_DIR/summary.tsv"
  stack_snapshot "$LOOP_DIR/processes-after.txt"
  if s10_reachable; then
    read -r uptime_value _ < /proc/uptime
    printf '%s\tpost_client\t%s\tPASS\t%s\n' "$loop" "$S10_IP" "$uptime_value" >> "$RUN_DIR/s10.tsv"
  else
    read -r uptime_value _ < /proc/uptime
    printf '%s\tpost_client\t%s\tFAIL\t%s\n' "$loop" "$S10_IP" "$uptime_value" >> "$RUN_DIR/s10.tsv"
    timeline s10_unreachable ",\"loop\":$loop,\"phase\":\"post_client\",\"s10Ip\":\"$S10_IP\""
  fi
  if [ -n "${session:-}" ]; then
    session_label=$(printf '%03d_session' "$session")
    cp "/root/d810-sessions/$session_label/bridge.log" "$LOOP_DIR/session-manager-bridge.log" 2>/dev/null || true
    cp "/root/d810-sessions/$session_label/ws.log" "$LOOP_DIR/ws.log" 2>/dev/null || true
  fi
  loop_backup_ok=1
  for artifact in \
    "$LOOP_DIR/client/steps.tsv" \
    "$LOOP_DIR/timings.tsv" \
    "$LOOP_DIR/battery.tsv" \
    "$LOOP_DIR/session-manager-bridge.log" \
    "$LOOP_DIR/bridge.log" \
    "$LOOP_DIR/ws.log"; do
    if [ -f "$artifact" ] && ! enqueue_artifact "$artifact" test-loop; then
      loop_backup_ok=0
    fi
  done
  if [ "$loop_backup_ok" -eq 1 ]; then
    rm -rf -- "$LOOP_DIR"
  fi
  loop=$((loop + 1))
  sleep 5
done

 timeline test_run_finished ",\"loops\":$COUNT"
enqueue_artifact "$RUN_DIR/summary.tsv" test-summary || true
enqueue_artifact "$RUN_DIR/timings.tsv" test-summary || true
enqueue_artifact "$RUN_DIR/battery.tsv" test-summary || true
enqueue_artifact "$RUN_DIR/s10.tsv" test-observer || true
enqueue_artifact "/root/d810-watch-logs/timeline-$(date +%Y%m%d).jsonl" test-observer || true
trap - EXIT INT TERM
cleanup
printf 'RUN_COMPLETE %s\n' "$RUN_DIR"
