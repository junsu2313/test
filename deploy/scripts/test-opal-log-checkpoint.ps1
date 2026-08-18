param()

$ErrorActionPreference = 'Stop'
$bash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path -LiteralPath $bash)) { throw 'Git Bash is required' }

$root = Join-Path ([IO.Path]::GetTempPath()) ('d810-log-checkpoint-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $checkpoint = (Resolve-Path (Join-Path $PSScriptRoot 'opal-log-checkpoint.sh')).Path
    $enqueue = (Resolve-Path (Join-Path $PSScriptRoot 'opal-outbox-enqueue.sh')).Path
    $unixRoot = (& $bash -lc "cygpath -u '$($root.Replace("'", "'\''"))'").Trim()
    $unixCheckpoint = (& $bash -lc "cygpath -u '$($checkpoint.Replace("'", "'\''"))'").Trim()
    $unixEnqueue = (& $bash -lc "cygpath -u '$($enqueue.Replace("'", "'\''"))'").Trim()
    $command = @"
set -eu
mkdir -p '$unixRoot/watch' '$unixRoot/sessions'
printf '%s\n' '{"event":"shot","traceId":"trace-1"}' > '$unixRoot/field.jsonl'
touch '$unixRoot/live'
D810_LOG_OUTBOX_ENQUEUE='$unixEnqueue' \
D810_LOG_CHECKPOINT_STATE_DIR='$unixRoot/state' \
D810_LOG_CHECKPOINT_LOCK='$unixRoot/lock' \
D810_LOG_CHECKPOINT_PENDING='$unixRoot/pending' \
D810D_SESSION_LIVE_REQUEST='$unixRoot/live' \
D810D_FIELD_EVENT_LOG='$unixRoot/field.jsonl' \
D810D_GLOBAL_LOG='$unixRoot/missing-camera.log' \
D810_WATCH_LOG_DIR='$unixRoot/watch' \
D810D_SESSION_LOG_ROOT='$unixRoot/sessions' \
D810_OUTBOX_DIR='$unixRoot/outbox' \
'/bin/sh' '$unixCheckpoint' force | grep -q '^deferred-live$'
test -f '$unixRoot/pending'
test "`$(find '$unixRoot/outbox' -name '*.ready' 2>/dev/null | wc -l)" = 0
rm '$unixRoot/live'
D810_LOG_OUTBOX_ENQUEUE='$unixEnqueue' \
D810_LOG_CHECKPOINT_STATE_DIR='$unixRoot/state' \
D810_LOG_CHECKPOINT_LOCK='$unixRoot/lock' \
D810_LOG_CHECKPOINT_PENDING='$unixRoot/pending' \
D810D_FIELD_EVENT_LOG='$unixRoot/field.jsonl' \
D810D_GLOBAL_LOG='$unixRoot/missing-camera.log' \
D810_WATCH_LOG_DIR='$unixRoot/watch' \
D810D_SESSION_LOG_ROOT='$unixRoot/sessions' \
D810_OUTBOX_DIR='$unixRoot/outbox' \
'/bin/sh' '$unixCheckpoint' boot
first=`$(find '$unixRoot/outbox' -name '*.ready' | wc -l)
test ! -e '$unixRoot/pending'
D810_LOG_OUTBOX_ENQUEUE='$unixEnqueue' \
D810_LOG_CHECKPOINT_STATE_DIR='$unixRoot/state' \
D810_LOG_CHECKPOINT_LOCK='$unixRoot/lock' \
D810D_FIELD_EVENT_LOG='$unixRoot/field.jsonl' \
D810D_GLOBAL_LOG='$unixRoot/missing-camera.log' \
D810_WATCH_LOG_DIR='$unixRoot/watch' \
D810D_SESSION_LOG_ROOT='$unixRoot/sessions' \
D810_OUTBOX_DIR='$unixRoot/outbox' \
'/bin/sh' '$unixCheckpoint' periodic
second=`$(find '$unixRoot/outbox' -name '*.ready' | wc -l)
D810_LOG_OUTBOX_ENQUEUE='$unixEnqueue' \
D810_LOG_CHECKPOINT_STATE_DIR='$unixRoot/state' \
D810_LOG_CHECKPOINT_LOCK='$unixRoot/lock' \
D810D_FIELD_EVENT_LOG='$unixRoot/field.jsonl' \
D810D_GLOBAL_LOG='$unixRoot/missing-camera.log' \
D810_WATCH_LOG_DIR='$unixRoot/watch' \
D810D_SESSION_LOG_ROOT='$unixRoot/sessions' \
D810_OUTBOX_DIR='$unixRoot/outbox' \
'/bin/sh' '$unixCheckpoint' force
forced=`$(find '$unixRoot/outbox' -name '*.ready' | wc -l)
printf '%s\n' '{"event":"preview","traceId":"trace-1"}' >> '$unixRoot/field.jsonl'
D810_LOG_OUTBOX_ENQUEUE='$unixEnqueue' \
D810_LOG_CHECKPOINT_STATE_DIR='$unixRoot/state' \
D810_LOG_CHECKPOINT_LOCK='$unixRoot/lock' \
D810D_FIELD_EVENT_LOG='$unixRoot/field.jsonl' \
D810D_GLOBAL_LOG='$unixRoot/missing-camera.log' \
D810_WATCH_LOG_DIR='$unixRoot/watch' \
D810D_SESSION_LOG_ROOT='$unixRoot/sessions' \
D810_OUTBOX_DIR='$unixRoot/outbox' \
'/bin/sh' '$unixCheckpoint' periodic
third=`$(find '$unixRoot/outbox' -name '*.ready' | wc -l)
test "`$first" = 1
test "`$second" = 1
test "`$forced" = 1
test "`$third" = 2
grep -q '^sha256=' '$unixRoot/outbox/'*.manifest
grep -q '"event":"preview"' '$unixRoot/outbox/'*.payload
"@
    & $bash -lc $command
    if ($LASTEXITCODE -ne 0) { throw "checkpoint integration failed: exit $LASTEXITCODE" }
    Write-Output 'PASS: live deferral, force deduplication, changed-log snapshot, and manifest integrity'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
