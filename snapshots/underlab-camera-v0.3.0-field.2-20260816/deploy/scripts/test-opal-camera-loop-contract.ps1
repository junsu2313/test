$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runner = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'opal-camera-loop-runner.sh') -Raw
$client = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'opal-virtual-camera-client.sh') -Raw
$ws = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'opal-virtual-client-ws.lua') -Raw
$launcher = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'opal-camera-loop-launch.sh') -Raw

foreach ($needle in @('stop_stack', 'stack_is_down', 'cycle_camera_usb', 'start_stack', 'test_loop_started', 'test_loop_passed', 'test_run_finished')) {
  if ($runner -notmatch [regex]::Escape($needle)) { throw "runner missing $needle" }
}
if ($runner -notmatch [regex]::Escape('bridge_request_timed STOP 8')) { throw 'runner must close the PTP session before stopping ddserver' }
if ($runner -notmatch [regex]::Escape("*'/www/cgi-bin/session-manager'*")) { throw 'runner must stop stale session-manager processes before serialized boot' }
if ($runner -notmatch [regex]::Escape('SESSION_STATE_SNAPSHOT="$RUN_DIR/session-v21.state"')) { throw 'runner must retain one session state snapshot across loops' }
if ($runner -notmatch [regex]::Escape('QUERY_STRING= /bin/sh "$CGI_DIR/session-manager"')) { throw 'runner must reuse the existing session instead of forcing reset=1' }
if ($runner -match [regex]::Escape('D810D_FIXED_SESSION_ID')) { throw 'runner must not force a fixed session id' }
if ($runner -notmatch [regex]::Escape('cp "$SESSION_STATE_SNAPSHOT" /tmp/d810-session-v21.state')) { throw 'runner must restore the fixed session before each boot' }
if ($runner -notmatch [regex]::Escape('timings.tsv')) { throw 'runner must persist per-segment timings' }
if ($runner -notmatch [regex]::Escape('start_stack "$LOOP_DIR/session-manager.out"')) { throw 'runner must persist the session-manager response per loop' }
if ($runner -notmatch [regex]::Escape('session=$(sed -n')) { throw 'runner must derive the session id from the manager response' }
if ($runner -notmatch [regex]::Escape('D810_TEST_BATTERY_MIN_PERCENT=${D810_TEST_BATTERY_MIN_PERCENT:-20}')) { throw 'runner must expose a battery stop threshold' }
if ($runner -notmatch [regex]::Escape('battery.tsv')) { throw 'runner must persist battery readings' }
if ($runner -notmatch [regex]::Escape('BATTERY_QUERY_INTERVAL_SEC=${D810_TEST_BATTERY_QUERY_INTERVAL_SEC:-600}')) { throw 'runner must use a ten-minute battery query interval' }
if ($runner -notmatch [regex]::Escape('S10_IP=${D810_TEST_S10_IP:-192.168.8.165}')) { throw 'runner must monitor the real S10 peer' }
if ($runner -notmatch [regex]::Escape('S10_PROBE_ATTEMPTS=${D810_TEST_S10_PROBE_ATTEMPTS:-3}')) { throw 'runner must retry transient S10 reachability failures' }
if ($runner -notmatch [regex]::Escape('s10.tsv')) { throw 'runner must persist S10 reachability readings' }
if ($runner -notmatch [regex]::Escape('S10_REQUIRED=${D810_TEST_S10_REQUIRED:-0}')) { throw 'runner must separate S10 observation from required gating' }
if ($runner -notmatch [regex]::Escape('storage.tsv')) { throw 'runner must persist storage guard readings' }
if ($runner -notmatch [regex]::Escape('enqueue_artifact')) { throw 'runner must enqueue test artifacts for backup' }
if ($runner -notmatch [regex]::Escape('status-v21?battery_probe=')) { throw 'runner must read battery through the bridge status path' }
if ($runner -notmatch [regex]::Escape('rm -rf -- "$LOOP_DIR"')) { throw 'runner must reclaim per-loop temporary storage after backup' }
if ($runner -notmatch [regex]::Escape('STOPPED_BATTERY')) { throw 'runner must stop cleanly when battery reaches the threshold' }
foreach ($needle in @('status-ready', 'action=af', 'action=live-on', 'websocket-frame', 'single-shutter', 'capture-event', 'captured-preview', 'captured-object', 'burst-3', 'action=live-off')) {
  if ($client -notmatch [regex]::Escape($needle)) { throw "client missing $needle" }
}
if ($ws -notmatch 'sock:bind\(source_ip') { throw 'WebSocket client must bind the virtual client IP' }
if ($ws -notmatch 'JPEG frame not received') { throw 'WebSocket client must require a JPEG frame' }
if ($launcher -notmatch 'exec /usr/bin/d810-camera-loop-runner') { throw 'launcher must hand off to the autonomous runner' }
Write-Output 'PASS: Opal autonomous camera loop contract'
