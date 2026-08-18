param()

$ErrorActionPreference = 'Stop'
$script = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'invoke-opal-chaos-soak.ps1') -Raw -Encoding utf8

if ($script -match 'action=shutter') { throw 'chaos soak must never trigger the shutter' }
if ($script -match 'rm -rf|firstboot|factoryreset') { throw 'chaos soak must not contain destructive reset operations' }
if ($script -notmatch 'Seed = 810') { throw 'chaos order must be reproducible from a seed' }
if ($script -notmatch 'bridge_websocket_term') { throw 'chaos soak must include a multi-process fault' }
if ($script -notmatch 'checkpoint_race') { throw 'chaos soak must exercise checkpoint contention' }
if ($script -notmatch 'Wait-Recovery') { throw 'every injected fault must be followed by bounded recovery verification' }
if ($script -notmatch '"transportReady"') { throw 'recovery must require a command-ready camera transport' }
if ($script -notmatch '"cameraDetected"') { throw 'recovery must require the physical camera to be detected' }
if ($script -notmatch 'd810-log-checkpoint periodic') { throw 'each scenario must checkpoint diagnostic evidence' }
if ($script -notmatch 'events.jsonl') { throw 'chaos soak must create structured local evidence' }

Write-Output 'PASS: shutter-free Opal chaos soak contract'
