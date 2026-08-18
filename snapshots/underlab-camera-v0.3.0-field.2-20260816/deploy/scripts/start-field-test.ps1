param(
  [int]$Loops = 20,
  [string]$S10Serial = '192.168.8.165:38917',
  [int]$BatteryMinPercent = 10,
  [int]$BatteryQueryIntervalSeconds = 600,
  [int]$OutboxIntervalSeconds = 60,
  [switch]$SkipSmoke
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$adbSmoke = Join-Path $PSScriptRoot 's10-field-ui-test.ps1'
$puller = Join-Path $PSScriptRoot 'start-opal-outbox-puller.ps1'
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
$key = Join-Path $root 'artifacts\ssh\opal-tailscale_rsa'
$sshArgs = @('-i',$key,'-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa','root@100.123.59.97')

if (-not $SkipSmoke) {
  Write-Output 'STEP s10_smoke START'
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $smokeOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adbSmoke -Serial $S10Serial -FrameWaitSeconds 5 -CaptureWaitSeconds 15 -KeepAwake 2>&1)
  $smokeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  $smokeOutput | ForEach-Object { Write-Output $_ }
  if ($smokeExitCode -ne 0 -or (($smokeOutput -join "`n") -notmatch 'S10_FIELD_TEST_COMPLETE')) {
    throw 'S10 smoke test failed; Opal loop was not started.'
  }
  Write-Output 'STEP s10_smoke PASS'
}

Write-Output 'STEP outbox_puller START'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -IntervalSeconds $OutboxIntervalSeconds
if ($LASTEXITCODE -ne 0) { throw 'Outbox puller failed to start.' }

$remote = "D810_TEST_S10_IP=192.168.8.165 D810_TEST_S10_REQUIRED=0 D810_TEST_BATTERY_MIN_PERCENT=$BatteryMinPercent D810_TEST_BATTERY_QUERY_INTERVAL_SEC=$BatteryQueryIntervalSeconds /usr/bin/d810-camera-loop-launch $Loops >/root/d810-test-runs/field-launch.log 2>&1 &"
Write-Output "STEP opal_loop START loops=$Loops battery_min=$BatteryMinPercent"
& $ssh @sshArgs $remote
if ($LASTEXITCODE -ne 0) { throw 'Opal loop failed to start.' }
Write-Output 'FIELD_TEST_STARTED'
Write-Output 'Monitor: powershell -File .\deploy\scripts\watch-opal-test.ps1 -ExpectedLoops <Loops>'
