#!/bin/sh
set -u

SOURCE_IP=${D810_TEST_CLIENT_IP:-192.168.8.250}
HOST=${D810_TEST_HOST:-192.168.8.1}
BASE_URL="http://$HOST"
WS_PORT=${D810_TEST_WS_PORT:-8191}
OUTPUT_DIR=${1:?output directory required}
WS_CLIENT=${D810_TEST_WS_CLIENT:-/usr/bin/d810-virtual-client-ws.lua}

mkdir -p "$OUTPUT_DIR"
STEPS="$OUTPUT_DIR/steps.tsv"
TIMELINE="$OUTPUT_DIR/timeline.jsonl"
printf 'step\tresult\tuptime_ms\tdetail\n' > "$STEPS"
printf '%s\n' '{"event":"probe_started"}' > "$TIMELINE"
TRACE_RUN=${D810_TEST_TRACE_ID:-field-$(date +%s)-$$}
failed=0

now_s() { cut -d' ' -f1 /proc/uptime; }
now_ms() { awk '{printf "%d\n", $1 * 1000}' /proc/uptime; }

record() {
  step=$1
  result=$2
  end_ms=$3
  detail=$4
  start_ms=${5:-$end_ms}
  duration_ms=$((end_ms - start_ms))
  printf '%s\t%s\t%s\t%s\tduration_ms=%s\n' "$step" "$result" "$end_ms" "$detail" "$duration_ms" >> "$STEPS"
  safe_detail=$(printf '%s' "$detail" | tr '\r\n\t"' '    ' | cut -c1-240)
  printf '{"event":"step_completed","traceId":"%s","step":"%s","result":"%s","startMs":%s,"endMs":%s,"durationMs":%s,"detail":"%s"}\n' \
    "$TRACE_RUN" "$step" "$result" "$start_ms" "$end_ms" "$duration_ms" "$safe_detail" >> "$TIMELINE"
}

request() {
  step=$1
  path=$2
  expect=$3
  output="$OUTPUT_DIR/$step.json"
  : > "$output"
  start_ms=$(now_ms)
  timing=$(curl --interface "$SOURCE_IP" --connect-timeout 3 --max-time 12 -sS \
      -H "X-D810-Trace: $TRACE_RUN-$step" -H "X-D810-Command-Id: $TRACE_RUN-$step-1" \
      -H 'X-D810-Client: field-probe' -w 'http_total_ms=%{time_total},ttfb_ms=%{time_starttransfer}' \
      "$BASE_URL$path" -o "$output" 2>/dev/null)
  curl_status=$?
  end_ms=$(now_ms)
  if [ "$curl_status" -eq 0 ] && grep -F "$expect" "$output" >/dev/null 2>&1; then
    record "$step" PASS "$end_ms" "$expect $timing" "$start_ms"
    return 0
  fi
  detail=$(tr '\r\n\t' '   ' < "$output" 2>/dev/null | cut -c1-240)
  record "$step" FAIL "$end_ms" "${detail:-request_failed} $timing" "$start_ms"
  failed=1
  return 1
}

request_jpeg() {
  step=$1
  path=$2
  output="$OUTPUT_DIR/$step.jpg"
  : > "$output"
  start_ms=$(now_ms)
  timing=$(curl --interface "$SOURCE_IP" --connect-timeout 3 --max-time 30 -sS \
      -H "X-D810-Trace: $TRACE_RUN-$step" -H "X-D810-Command-Id: $TRACE_RUN-$step-1" \
      -H 'X-D810-Client: field-probe' -w 'http_total_ms=%{time_total},ttfb_ms=%{time_starttransfer}' \
      "$BASE_URL$path" -o "$output" 2>/dev/null)
  curl_status=$?
  end_ms=$(now_ms)
  if [ "$curl_status" -eq 0 ] && \
      [ "$(wc -c < "$output")" -gt 1024 ] && \
      [ "$(head -c 2 "$output" | hexdump -v -e '1/1 "%02x"')" = "ffd8" ]; then
    record "$step" PASS "$end_ms" "bytes=$(wc -c < "$output") $timing" "$start_ms"
    return 0
  fi
  record "$step" FAIL "$end_ms" "jpeg_invalid $timing" "$start_ms"
  failed=1
  return 1
}

wait_ready() {
  attempt=1
  while [ "$attempt" -le 30 ]; do
    output="$OUTPUT_DIR/status-ready-$attempt.json"
    start_ms=$(now_ms)
    if curl --interface "$SOURCE_IP" --connect-timeout 2 --max-time 8 -sS \
        -H 'Cache-Control: no-cache' -H "X-D810-Trace: $TRACE_RUN-status-ready-$attempt" \
        -H "X-D810-Command-Id: $TRACE_RUN-status-ready-$attempt-1" -H 'X-D810-Client: field-probe' \
        "$BASE_URL/cgi-bin/status-v21?t=$(date +%s)" -o "$output" && \
        grep -F '"ok":true' "$output" >/dev/null 2>&1 && \
        grep -F '"cameraDetected":true' "$output" >/dev/null 2>&1 && \
        grep -F '"hardwareDetected":true' "$output" >/dev/null 2>&1 && \
        grep -F '"transportReady":true' "$output" >/dev/null 2>&1; then
      cp "$output" "$OUTPUT_DIR/status-ready.json"
      end_ms=$(now_ms)
      record status-ready PASS "$end_ms" "attempt=$attempt" "$start_ms"
      return 0
    fi
    end_ms=$(now_ms)
    record "status-ready-$attempt" FAIL "$end_ms" "attempt=$attempt" "$start_ms"
    sleep 1
    attempt=$((attempt + 1))
  done
  record status-ready FAIL "$(now_ms)" "timeout"
  failed=1
  return 1
}

cleanup() {
  curl --interface "$SOURCE_IP" --connect-timeout 2 --max-time 12 -sS \
    "$BASE_URL/cgi-bin/action-v21?action=shutter-hold-stop" >/dev/null 2>&1 || true
  curl --interface "$SOURCE_IP" --connect-timeout 2 --max-time 12 -sS \
    "$BASE_URL/cgi-bin/action-v21?action=live-off" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

wait_ready || true
request live-on '/cgi-bin/action-v21?action=live-on' '"status":"liveview_on"' || true

ws_start_ms=$(now_ms)
if timeout -t 20 /usr/bin/lua "$WS_CLIENT" "$SOURCE_IP" "$HOST" "$WS_PORT" "$OUTPUT_DIR/websocket-frame.jpg" \
    > "$OUTPUT_DIR/websocket.log" 2>&1; then
  record websocket-frame PASS "$(now_ms)" "$(cat "$OUTPUT_DIR/websocket.log")" "$ws_start_ms"
else
  record websocket-frame FAIL "$(now_ms)" "$(tr '\r\n\t' '   ' < "$OUTPUT_DIR/websocket.log" | cut -c1-240)" "$ws_start_ms"
  failed=1
fi

http_frame_start_ms=$(now_ms)
http_frame_timing=$(curl --interface "$SOURCE_IP" --connect-timeout 3 --max-time 12 -sS \
    -H 'Cache-Control: no-cache' -H "X-D810-Trace: $TRACE_RUN-http-frame" \
    -H "X-D810-Command-Id: $TRACE_RUN-http-frame-1" -H 'X-D810-Client: field-probe' \
    -w 'http_total_ms=%{time_total},ttfb_ms=%{time_starttransfer}' \
    "$BASE_URL/cgi-bin/liveview-v21?t=$(date +%s)" -o "$OUTPUT_DIR/http-frame.jpg" 2>/dev/null)
http_frame_status=$?
http_frame_end_ms=$(now_ms)
if [ "$http_frame_status" -eq 0 ] && \
    [ "$(wc -c < "$OUTPUT_DIR/http-frame.jpg")" -gt 1024 ] && \
    [ "$(head -c 2 "$OUTPUT_DIR/http-frame.jpg" | hexdump -v -e '1/1 "%02x"')" = "ffd8" ]; then
  record http-frame PASS "$http_frame_end_ms" "bytes=$(wc -c < "$OUTPUT_DIR/http-frame.jpg") $http_frame_timing" "$http_frame_start_ms"
else
  record http-frame FAIL "$http_frame_end_ms" "frame_invalid $http_frame_timing" "$http_frame_start_ms"
  failed=1
fi

request af '/cgi-bin/action-v21?action=af' '"ok":true' || true

request single-hold-start '/cgi-bin/action-v21?action=shutter-hold-start' '"ok":true' || true
request single-shutter '/cgi-bin/action-v21?action=shutter' '"ok":true' || true
request single-hold-stop '/cgi-bin/action-v21?action=shutter-hold-stop' '"ok":true' || true
settle_start_ms=$(now_ms)
sleep 3
record capture-settle PASS "$(now_ms)" 'sleep_ms=3000' "$settle_start_ms"
request capture-event '/cgi-bin/capture-event?probe='"$(date +%s)" '"captureEvent":true' || true
request_jpeg captured-preview '/cgi-bin/captured-preview?probe='"$(date +%s)" || true
request_jpeg captured-object '/cgi-bin/captured-object' || true

request burst-hold-start '/cgi-bin/action-v21?action=shutter-hold-start' '"ok":true' || true
request burst-1 '/cgi-bin/action-v21?action=shutter' '"ok":true' || true
request burst-2 '/cgi-bin/action-v21?action=shutter' '"ok":true' || true
request burst-3 '/cgi-bin/action-v21?action=shutter' '"ok":true' || true
request burst-hold-stop '/cgi-bin/action-v21?action=shutter-hold-stop' '"ok":true' || true
request live-off '/cgi-bin/action-v21?action=live-off' '"ok":true' || true

trap - EXIT INT TERM
cleanup
printf '{"event":"probe_finished","traceId":"%s","failed":%s}\n' "$TRACE_RUN" "$failed" >> "$TIMELINE"
[ "$failed" -eq 0 ]
