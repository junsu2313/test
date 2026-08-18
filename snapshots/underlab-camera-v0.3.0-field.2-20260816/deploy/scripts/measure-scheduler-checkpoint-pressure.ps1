param(
  [string]$Adb = 'C:\Android\platform-tools\adb.exe',
  [string]$Serial = '192.168.8.165:40057',
  [string]$Ssh = 'C:\Windows\System32\OpenSSH\ssh.exe',
  [string]$Opal = 'root@100.123.59.97',
  [string]$Key = 'artifacts\ssh\opal-tailscale_rsa',
  [int]$DurationSeconds = 70,
  [int]$PressureAtSeconds = 20
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$output = Join-Path $root 'artifacts\frame-id'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$s10Path = Join-Path $output "$stamp-s10-checkpoint-pressure.log"
$opalPath = Join-Path $output "$stamp-opal-checkpoint-pressure.json"
$eventPath = Join-Path $output "$stamp-checkpoint-pressure-events.log"
$keyPath = Join-Path $root $Key

& $Adb connect $Serial | Out-Null
& $Adb -s $Serial logcat -c
& $Adb -s $Serial shell input tap 1370 1247
Start-Sleep -Seconds 2

$logJob = Start-Job -ScriptBlock {
  param($AdbPath, $Device)
  & $AdbPath -s $Device logcat -v epoch 'EVF_PULSE:I' 'EVF_BENCH:I' '*:S'
} -ArgumentList $Adb, $Serial

$opalJob = Start-Job -ScriptBlock {
  param($SshPath, $Identity, $Target, $Duration)
  & $SshPath -i $Identity -o BatchMode=yes -o ConnectTimeout=5 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa $Target "/usr/bin/lua /tmp/opal-liveview-frame-id-monitor.lua $Duration checkpoint-pressure" 2>&1
} -ArgumentList $Ssh, $keyPath, $Opal, $DurationSeconds

$started = Get-Date
try {
  Start-Sleep -Seconds $PressureAtSeconds
  $pressureStarted = Get-Date
  $checkpointOutput = & $Ssh -i $keyPath -o BatchMode=yes -o ConnectTimeout=5 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa $Opal '/usr/bin/time -f elapsed=%e /usr/bin/d810-log-checkpoint force' 2>&1
  $pressureEnded = Get-Date
  @(
    "measurement_started=$($started.ToString('o'))"
    "pressure_started=$($pressureStarted.ToString('o'))"
    "pressure_ended=$($pressureEnded.ToString('o'))"
    "pressure_elapsed_ms=$([Math]::Round(($pressureEnded - $pressureStarted).TotalMilliseconds))"
    "checkpoint_output=$($checkpointOutput -join ' ')"
  ) | Set-Content -Encoding utf8 $eventPath
  $remaining = $DurationSeconds - [int][Math]::Floor(((Get-Date) - $started).TotalSeconds)
  if ($remaining -gt 0) { Start-Sleep -Seconds $remaining }
}
finally {
  & $Adb -s $Serial shell input tap 1650 1247 | Out-Null
  Stop-Job $logJob -ErrorAction SilentlyContinue
  Receive-Job $logJob -ErrorAction SilentlyContinue | Set-Content -Encoding utf8 $s10Path
  Wait-Job $opalJob -Timeout 10 | Out-Null
  Receive-Job $opalJob -ErrorAction SilentlyContinue | Set-Content -Encoding utf8 $opalPath
  Remove-Job $logJob, $opalJob -Force -ErrorAction SilentlyContinue
}

[pscustomobject]@{
  S10 = $s10Path
  Opal = $opalPath
  Events = $eventPath
} | ConvertTo-Json
