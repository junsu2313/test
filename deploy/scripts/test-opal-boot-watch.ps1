param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot '..\scripts\opal-boot-watch.sh'),
    [string]$CheckpointPath = (Join-Path $PSScriptRoot '..\scripts\opal-log-checkpoint.sh'),
    [string]$OutboxPath = (Join-Path $PSScriptRoot '..\scripts\opal-outbox-enqueue.sh')
)

$ErrorActionPreference = 'Stop'
$script = Get-Content -LiteralPath $ScriptPath -Raw
$checkpoint = Get-Content -LiteralPath $CheckpointPath -Raw
$outbox = Get-Content -LiteralPath $OutboxPath -Raw

if ($script -notmatch 'boot_started') { throw 'watcher must record boot_started' }
if ($script -notmatch 'wifi_station_connected') { throw 'watcher must record Wi-Fi station connections' }
if ($script -notmatch 'service_ready') { throw 'watcher must record service readiness' }
if ($script -notmatch 'camera_ready') { throw 'watcher must record camera readiness' }
if ($script -notmatch 'app_connected') { throw 'watcher must record app connectivity' }
if ($script -notmatch 'd810-watch-logs') { throw 'watcher must have a dedicated persistent log directory' }
if ($script -notmatch 'emit heartbeat') { throw 'watcher must periodically record the camera stack state' }
if ($script -notmatch 'runtime_guardian_pid') { throw 'heartbeat must include related camera services' }
if ($script -notmatch 'acquire_singleton \|\| exit 0') { throw 'watcher must reject duplicate processes' }
if ($script -notmatch 'D810_WATCH_LOCK') { throw 'watcher singleton lock must be configurable' }
if ($script -notmatch '"\$CHECKPOINT_SCRIPT" boot') { throw 'watcher must recover uncheckpointed logs at boot' }
if ($script -notmatch '"\$CHECKPOINT_SCRIPT" periodic') { throw 'watcher must checkpoint logs while running' }
if ($checkpoint -notmatch 'sha256sum "\$source"') { throw 'checkpoint must deduplicate snapshots by content hash' }
if ($checkpoint -notmatch 'd810-field-events.jsonl') { throw 'checkpoint must include structured action events' }
if ($checkpoint -notmatch 'd810-camera-events.log') { throw 'checkpoint must include camera bridge events' }
if ($checkpoint -notmatch 'session-bridge') { throw 'checkpoint must include the active session bridge log' }
if ($checkpoint -notmatch '(?m)^\s*sync$') { throw 'checkpoint must flush newly persistent writes before returning' }
if ($checkpoint -notmatch 'ALLOW_FORCE_WHILE_LIVE') { throw 'forced checkpoints must defer behind live view by default' }
if ($checkpoint -notmatch 'checkpoint_count') { throw 'unchanged checkpoints must skip the global flash flush' }
if ($outbox -notmatch 'sha256=') { throw 'outbox manifest must retain a payload hash' }
if ($outbox -notmatch 'while \[ -e "\$OUTBOX/\$id.payload"') { throw 'outbox ids must not overwrite an existing payload' }

Write-Output 'PASS: Opal boot watcher contract'
