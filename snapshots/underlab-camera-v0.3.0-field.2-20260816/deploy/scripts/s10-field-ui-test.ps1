param(
  [string]$Serial = '192.168.8.165:38917',
  [int]$FrameWaitSeconds = 5,
  [int]$CaptureWaitSeconds = 15,
  [switch]$KeepAwake
)

$ErrorActionPreference = 'Stop'
$adb = 'C:\Android\platform-tools\adb.exe'
$package = 'com.example.underlab_camera'
$root = Join-Path ([IO.Path]::GetTempPath()) 's10-field-tests'
$run = Join-Path $root (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Path $run -Force | Out-Null

function Adb([string[]]$CommandArgs) {
  & $adb -s $Serial @CommandArgs
  if ($LASTEXITCODE -ne 0) { throw "adb failed: $($CommandArgs -join ' ')" }
}

function Record([string]$Step, [string]$Result, [string]$Detail = '') {
  [pscustomobject]@{
    time = (Get-Date).ToString('o')
    step = $Step
    result = $Result
    detail = $Detail
  } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $run 'steps.jsonl')
}

function Screenshot([string]$Name) {
  $path = Join-Path $run "$Name.png"
  & $adb -s $Serial exec-out screencap -p > $path
  if ($LASTEXITCODE -ne 0) { Record $Name FAIL 'screenshot_failed' }
}

function Tap([string]$Step, [int]$X, [int]$Y) {
  Adb @('shell','input','tap',"$X","$Y")
  Record $Step PASS "tap=($X,$Y)"
  Start-Sleep -Milliseconds 500
}

if (-not (Test-Path -LiteralPath $adb)) { throw "adb not found: $adb" }
Adb @('connect', $Serial)
$devices = (& $adb devices) -join "`n"
if ($devices -notmatch [regex]::Escape("$Serial`tdevice")) { throw "S10 is not online: $Serial" }
Record 'adb_connected' PASS $Serial

Adb @('shell','monkey','-p',$package,'1')
Start-Sleep -Seconds 2
$focus = (& $adb -s $Serial shell dumpsys window) -join "`n"
if ($focus -notmatch [regex]::Escape($package)) { throw 'S10 app is not foreground' }
Record 'app_foreground' PASS $package
Screenshot 'before'

if ($KeepAwake) {
  Adb @('shell','input','tap','1000','700')
  Record 'keepalive_probe' PASS 'tap=(1000,700)'
}

Tap 'live_on' 1370 1247
Start-Sleep -Seconds $FrameWaitSeconds
Screenshot 'liveview'
Record 'liveview_wait' PASS "wait=${FrameWaitSeconds}s"

Tap 'af_shot' 2247 1249
Start-Sleep -Seconds $CaptureWaitSeconds
Screenshot 'after_capture'
Record 'capture_wait' PASS "wait=${CaptureWaitSeconds}s"

Tap 'live_off' 1650 1247
Start-Sleep -Seconds 2
Screenshot 'after_live_off'
Record 'completed' PASS "run=$run"
Write-Output "S10_FIELD_TEST_COMPLETE $run"
