param(
  [string]$SuitePath = (Join-Path $PSScriptRoot '..\..\docs\chaos-automated-pipeline-suite-seed810.csv'),
  [string]$RunId = '',
  [switch]$ResumeLatest,
  [int]$MaxCases = 0,
  [switch]$DryRun,
  [switch]$Unattended,
  [int]$MaxConsecutiveFailures = 3,
  [string]$ConfirmManualCase = '',
  [string]$InvalidateCase = '',
  [string]$InvalidateReason = '',
  [string]$OpalAddress = '192.168.8.1',
  [string]$S10Serial = '',
  [string]$S10Address = '192.168.8.165',
  [string]$AdbPath = 'C:\Android\platform-tools\adb.exe',
  [string]$KeyFile = (Join-Path $PSScriptRoot '..\..\artifacts\ssh\opal-tailscale_rsa'),
  [int]$RecoveryTimeoutSeconds = 90,
  [int]$MinFreeKilobytes = 5120,
  [int]$MaxResidualReady = 4
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$resultsRoot = Join-Path $repoRoot 'chaos-results\pipeline-suite'
$suiteResolved = (Resolve-Path -LiteralPath $SuitePath).Path
function Get-Sha256Hex {
  param([string]$Path)
  $stream = [IO.File]::OpenRead($Path)
  try {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
  } finally { $stream.Dispose() }
}
$suiteHash = Get-Sha256Hex $suiteResolved
$ssh = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$puller = Join-Path $PSScriptRoot 'pull-opal-outbox.ps1'
$stages = @('preflight','d810','ddserver','session_manager','s10','operating_mode','log_profile','delivery_profile','ordered_race','final_assert')

if (-not (Test-Path -LiteralPath $KeyFile)) { throw "SSH key not found: $KeyFile" }
if (-not (Test-Path -LiteralPath $ssh)) { throw "SSH executable not found: $ssh" }
[IO.Directory]::CreateDirectory($resultsRoot) | Out-Null

if ($ResumeLatest) {
  $latest = Get-ChildItem -LiteralPath $resultsRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'state.json') } |
    Select-Object -First 1
  if (-not $latest) { throw 'No resumable pipeline run exists.' }
  $RunId = $latest.Name
}
if (-not $RunId) { $RunId = 'pipeline-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
if ($RunId -notmatch '^[A-Za-z0-9._-]+$') { throw 'RunId contains unsupported characters.' }

$runRoot = Join-Path $resultsRoot $RunId
$casesRoot = Join-Path $runRoot 'cases'
$statePath = Join-Path $runRoot 'state.json'
$eventsPath = Join-Path $runRoot 'events.jsonl'
$lockPath = Join-Path $runRoot 'run.lock'
[IO.Directory]::CreateDirectory($casesRoot) | Out-Null

function Write-AtomicJson {
  param([string]$Path, [object]$Value)
  $temporary = "$Path.tmp.$PID"
  $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding utf8
  Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Save-State {
  $script:state.updatedAt = (Get-Date).ToString('o')
  Write-AtomicJson $statePath $script:state
}

function Write-Event {
  param([string]$Event, [string]$CaseId = '', [string]$Stage = '', [string]$Result = '', [string]$Detail = '')
  $row = [ordered]@{
    at = (Get-Date).ToString('o'); runId = $RunId; event = $Event
    caseId = $CaseId; stage = $Stage; result = $Result; detail = $Detail
  }
  $json = $row | ConvertTo-Json -Compress
  $written = $false
  for ($attempt = 1; $attempt -le 20; $attempt++) {
    try {
      $stream = [IO.File]::Open($eventsPath,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
      try {
        $writer = [IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false))
        try { $writer.WriteLine($json); $writer.Flush() } finally { $writer.Dispose() }
      } catch {
        $stream.Dispose()
        throw
      }
      $written = $true
      break
    } catch [IO.IOException] {
      if ($attempt -eq 20) { throw }
      Start-Sleep -Milliseconds ([Math]::Min(500,25 * $attempt))
    }
  }
  if (-not $written) { throw 'event log append retry budget exhausted' }
  Write-Output ("{0} {1} {2} {3} {4}" -f $Event,$CaseId,$Stage,$Result,$Detail).Trim()
}

if (Test-Path -LiteralPath $statePath) {
  $script:state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($script:state.suiteHash -ne $suiteHash) { throw 'Suite changed after this run started; refusing unsafe resume.' }
  if ($script:state.status -eq 'FAILED' -and $script:state.currentCase) {
    $unfinishedPath = Join-Path $casesRoot "$($script:state.currentCase).json"
    if (-not (Test-Path -LiteralPath $unfinishedPath)) {
      $script:state.failed = [Math]::Max(0,[int]$script:state.failed - 1)
      $script:state.status = 'PAUSED'
      $script:state.waitingReason = ''
      Save-State
    }
  }
} else {
  $script:state = [pscustomobject]@{
    schemaVersion = 1; runId = $RunId; suitePath = $suiteResolved; suiteHash = $suiteHash
    status = 'READY'; currentCase = ''; nextStage = 0; completed = 0; passed = 0; failed = 0
    waitingReason = ''; s10Serial = ''; createdAt = (Get-Date).ToString('o'); updatedAt = (Get-Date).ToString('o')
  }
  Save-State
}

if ($InvalidateCase) {
  if ($InvalidateCase -notmatch '^(PIPE-[0-9]{3}|AUTO-[0-9]{3}|PWR-[0-9]{3}|USB-[0-9]{3}|RACE-[0-9]{2})$') { throw 'Invalid case id for invalidation.' }
  if (-not $InvalidateReason) { throw 'InvalidateReason is required.' }
  $casePath = Join-Path $casesRoot "$InvalidateCase.json"
  if (-not (Test-Path -LiteralPath $casePath)) { throw "Completed case not found: $InvalidateCase" }
  $invalidRoot = Join-Path $runRoot 'invalidated'
  [IO.Directory]::CreateDirectory($invalidRoot) | Out-Null
  $invalidPath = Join-Path $invalidRoot ("{0}-{1}.json" -f $InvalidateCase,(Get-Date -Format 'yyyyMMdd-HHmmss'))
  Move-Item -LiteralPath $casePath -Destination $invalidPath
  $incident = [ordered]@{ caseId=$InvalidateCase; invalidatedAt=(Get-Date).ToString('o'); reason=$InvalidateReason; preservedResult=$invalidPath }
  Write-AtomicJson (Join-Path $invalidRoot ("{0}-incident.json" -f $InvalidateCase)) $incident
  $script:state.completed = [Math]::Max(0,[int]$script:state.completed - 1)
  $script:state.passed = [Math]::Max(0,[int]$script:state.passed - 1)
  $script:state.status = 'PAUSED'; $script:state.currentCase = ''; $script:state.nextStage = 0
  $script:state.waitingReason = "Invalidated ${InvalidateCase}: $InvalidateReason"
  Save-State
  Write-Output "INVALIDATED=$InvalidateCase preserved=$invalidPath"
  exit 0
}

if (Test-Path -LiteralPath $lockPath) {
  $oldPid = Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($oldPid -match '^\d+$' -and (Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue)) {
    throw "Pipeline runner is already active (pid=$oldPid)."
  }
}
Set-Content -LiteralPath $lockPath -Value $PID -Encoding ascii

$sshOptions = @(
  '-i',$KeyFile,'-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o','HostKeyAlias=192.168.8.1','-o','BatchMode=yes','-o','ConnectTimeout=5',
  '-o','ServerAliveInterval=5','-o','ServerAliveCountMax=2'
)

function Invoke-Remote {
  param([Parameter(Mandatory=$true)][string]$Command)
  if ($DryRun) { return [pscustomobject]@{ ExitCode=0; Output="DRYRUN $Command" } }
  $output = @(& $ssh @sshOptions "root@$OpalAddress" $Command 2>&1)
  [pscustomobject]@{ ExitCode=$LASTEXITCODE; Output=($output -join "`n") }
}

function Get-Health {
  $command = @'
alive_pidfile() { p=$(cat "$1" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
http=$(wget -T 6 -qO- http://127.0.0.1/cgi-bin/status-v21 2>/dev/null || true)
alive_pidfile /tmp/d810-bridge-v21.pid && bridge=1 || bridge=0
alive_pidfile /tmp/d810-ws-v21.pid && websocket=1 || websocket=0
alive_pidfile /tmp/d810-runtime-guardian.pid && guardian=1 || guardian=0
alive_pidfile /tmp/d810-session-health.pid && health=1 || health=0
pidof ddserver >/dev/null 2>&1 && ddserver=1 || ddserver=0
printf 'bridge=%s websocket=%s guardian=%s health=%s ddserver=%s status=%s\n' "$bridge" "$websocket" "$guardian" "$health" "$ddserver" "$http"
'@
  $result = Invoke-Remote $command
  if ($DryRun) { return [pscustomobject]@{ Healthy=$true; Detail='dry-run healthy' } }
  $healthy = $result.ExitCode -eq 0 -and $result.Output -match 'bridge=1' -and
    $result.Output -match 'websocket=1' -and $result.Output -match 'guardian=1' -and
    $result.Output -match 'health=1' -and $result.Output -match 'ddserver=1' -and
    $result.Output -match '"ok"\s*:\s*true' -and $result.Output -match '"cameraDetected"\s*:\s*true' -and
    $result.Output -match '"transportReady"\s*:\s*true' -and $result.Output -match '"status"\s*:\s*"ready"'
  [pscustomobject]@{ Healthy=$healthy; Detail=$result.Output }
}

function Wait-Healthy {
  $deadline = (Get-Date).AddSeconds($RecoveryTimeoutSeconds)
  do {
    $health = Get-Health
    if ($health.Healthy) { return $health }
    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)
  throw "Health did not recover: $($health.Detail)"
}

function Get-FreeKilobytes {
  if ($DryRun) { return 999999 }
  $result = Invoke-Remote "df -Pk / | awk 'NR==2 {print `$4}'"
  if ($result.ExitCode -ne 0 -or $result.Output -notmatch '^\s*(\d+)\s*$') { throw "Unable to read Opal free space: $($result.Output)" }
  return [int64]$Matches[1]
}

function Get-OutboxReadyCount {
  if ($DryRun) { return 0 }
  $result = Invoke-Remote "find /root/d810-outbox -maxdepth 1 -name '*.ready' | wc -l"
  if ($result.ExitCode -ne 0 -or $result.Output -notmatch '^\s*(\d+)\s*$') { throw "Unable to read outbox count: $($result.Output)" }
  return [int]$Matches[1]
}

function Require-StorageSafety {
  param([string]$CaseId, [string]$Stage)
  $freeKb = Get-FreeKilobytes
  if ($freeKb -ge $MinFreeKilobytes) { return }
  $instruction = "Opal free space ${freeKb}KB is below safety floor ${MinFreeKilobytes}KB; drain outbox before resume"
  $script:state.status = 'SAFETY_WAIT'
  $script:state.waitingReason = $instruction
  Save-State
  Write-Event 'safety_wait' $CaseId $Stage 'WAITING' $instruction
  throw [System.OperationCanceledException]::new($instruction)
}

function Invoke-StatusProbe {
  param([string]$Trace)
  $result = Invoke-Remote "HTTP_X_D810_TRACE='$Trace' HTTP_X_D810_COMMAND_ID='$Trace-1' HTTP_X_D810_CLIENT='pipeline-suite' QUERY_STRING='action=manual-status' /www/cgi-bin/action-v21"
  if ($result.ExitCode -ne 0) { throw "status probe failed: $($result.Output)" }
}

function Require-Manual {
  param([string]$CaseId, [string]$Instruction)
  if ($DryRun) { return }
  if ($Unattended) { throw "UNATTENDED_BLOCK: $Instruction" }
  if ($ConfirmManualCase -eq $CaseId) {
    [void](Wait-Healthy)
    return
  }
  $script:state.status = 'WAITING'
  $script:state.waitingReason = $Instruction
  Save-State
  Write-Event 'manual_wait' $CaseId $stages[[int]$script:state.nextStage] 'WAITING' $Instruction
  throw [System.OperationCanceledException]::new("WAITING: $Instruction; resume with -RunId $RunId -ConfirmManualCase $CaseId")
}

function Require-Adb {
  param([string]$CaseId, [switch]$ProbeOnly)
  if ($DryRun) { return $true }
  if (-not (Test-Path -LiteralPath $AdbPath)) {
    if ($ProbeOnly) { return $false }
    Require-Manual $CaseId "ADB executable unavailable: $AdbPath"; return $false
  }
  $candidates = @()
  if ($S10Serial) { $candidates += $S10Serial }
  if ($script:state.PSObject.Properties.Name -contains 's10Serial' -and $script:state.s10Serial) { $candidates += $script:state.s10Serial }
  $deviceLines = @(& $AdbPath devices)
  foreach ($line in $deviceLines) {
    if ($line -match "^($([regex]::Escape($S10Address)):\d+)\s+device$") { $candidates += $Matches[1] }
  }
  $mdnsLines = @(& $AdbPath mdns services 2>$null)
  foreach ($line in $mdnsLines) {
    if ($line -match "($([regex]::Escape($S10Address)):\d+)") {
      $mdnsCandidate = $Matches[1]
      if ($line -match '_adb-tls-connect') { $candidates += $mdnsCandidate }
    }
  }
  foreach ($candidate in @($candidates | Select-Object -Unique)) {
    & $AdbPath connect $candidate | Out-Null
    $devices = (& $AdbPath devices) -join "`n"
    if ($devices -match [regex]::Escape("$candidate`tdevice")) {
      $script:ResolvedS10Serial = $candidate
      if ($script:state.PSObject.Properties.Name -notcontains 's10Serial') { $script:state | Add-Member -NotePropertyName s10Serial -NotePropertyValue $candidate }
      else { $script:state.s10Serial = $candidate }
      Save-State
      return $true
    }
  }
  if ($ProbeOnly) { return $false }
  Require-Manual $CaseId "Enable S10 wireless debugging; the runner will discover the current port automatically"
  return $false
}

function Wait-AdbReconnect {
  param([string]$CaseId, [int]$TimeoutSeconds = 45)
  $script:ResolvedS10Serial = ''
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    if (Require-Adb $CaseId -ProbeOnly) { return }
    Start-Sleep -Seconds 3
  } while ((Get-Date) -lt $deadline)
  Require-Manual $CaseId 'S10 Wi-Fi or wireless debugging did not reconnect automatically'
}

function Invoke-S10WirelessContinuity {
  param([string]$CaseId, [string]$Trace)
  if ($DryRun) { return }
  $ping = Test-Connection -ComputerName $S10Address -Count 1 -Quiet
  if (-not $ping) {
    Require-Manual $CaseId 'S10 is not reachable on the Opal Wi-Fi network'
  }
  Invoke-StatusProbe $Trace
  Write-Event 'fault_skipped' $CaseId 's10' 'SKIP' 'wireless disconnect disabled; continuity probe only'
}

function Invoke-Adb {
  param([string[]]$Arguments)
  if ($DryRun) { return }
  & $AdbPath -s $script:ResolvedS10Serial @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
}

function Invoke-Stage {
  param([pscustomobject]$Case, [string]$Stage)
  $caseId = $Case.case_id
  $trace = "$RunId-$caseId-$Stage"
  switch ($Stage) {
    'preflight' { [void](Wait-Healthy) }
    'd810' {
      switch ($Case.d810) {
        'ready' { Invoke-StatusProbe $trace }
        'standby_wake' { if (-not $DryRun) { Start-Sleep -Seconds 15 }; Invoke-StatusProbe $trace }
        'usb_reconnect' { Require-Manual $caseId 'Reconnect the D810 USB cable, wait for Ready, then confirm this case.' }
        'power_cycle_recover' { Require-Manual $caseId 'Power-cycle the D810, wait for Ready, then confirm this case.' }
        'post_power_cycle_recover' { Invoke-StatusProbe $trace }
        'post_usb_reconnect' { Invoke-StatusProbe $trace }
        default { throw "Unknown D810 condition: $($Case.d810)" }
      }
    }
    'ddserver' {
      switch ($Case.ddserver) {
        'healthy' { Invoke-StatusProbe $trace }
        'term_recover' { [void](Invoke-Remote 'p=$(pidof ddserver | awk ''{print $1}''); [ -n "$p" ] && kill "$p"'); [void](Wait-Healthy) }
        'restart_during_request' {
          $command = '(HTTP_X_D810_TRACE=''__TRACE__'' QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1) & sleep 1; /etc/init.d/ddserver restart; wait'
          $result = Invoke-Remote ($command.Replace('__TRACE__',$trace)); if ($result.ExitCode -ne 0) { throw $result.Output }; [void](Wait-Healthy)
        }
      }
    }
    'session_manager' {
      switch ($Case.session_manager) {
        'stable' { Invoke-StatusProbe $trace }
        'bridge_term_recover' { [void](Invoke-Remote 'p=$(cat /tmp/d810-bridge-v21.pid); [ -n "$p" ] && kill "$p"'); [void](Wait-Healthy) }
        'stale_session_repair' {
          [void](Invoke-Remote 'touch /tmp/d810-session.live /tmp/d810-session.repair; sleep 4; QUERY_STRING=''action=live-off'' /www/cgi-bin/action-v21 >/dev/null 2>&1; rm -f /tmp/d810-session.live'); [void](Wait-Healthy)
        }
        'websocket_reconnect' { [void](Invoke-Remote 'p=$(cat /tmp/d810-ws-v21.pid); [ -n "$p" ] && kill "$p"'); [void](Wait-Healthy) }
      }
    }
    's10' {
      switch ($Case.s10) {
        'foreground' { Require-Adb $caseId; Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1') }
        'background_resume' { Require-Adb $caseId; Invoke-Adb @('shell','input','keyevent','HOME'); if (-not $DryRun) { Start-Sleep -Seconds 2 }; Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1') }
        'force_stop_relaunch' { Require-Adb $caseId; Invoke-Adb @('shell','am','force-stop','com.example.underlab_camera'); Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1') }
        'wifi_reconnect' { Invoke-S10WirelessContinuity $caseId $trace }
        'wireless_continuity' { Invoke-S10WirelessContinuity $caseId $trace }
      }
    }
    'operating_mode' {
      $action = if ($Case.operating_mode -eq 'liveview') { 'live-on' } else { 'live-off' }
      $result = Invoke-Remote "HTTP_X_D810_TRACE='$trace' QUERY_STRING='action=$action' /www/cgi-bin/action-v21 >/dev/null 2>&1"
      if ($result.ExitCode -ne 0) { throw "mode action failed: $action" }
    }
    'log_profile' {
      switch ($Case.log_profile) {
        'normal' { [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1') }
        'trace_burst' { [void](Invoke-Remote 'i=0; while [ $i -lt 40 ]; do i=$((i+1)); QUERY_STRING=''action=trace'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done') }
        'rotation_boundary' {
          $result = Invoke-Remote 'free=$(df -k / | awk ''NR==2 {print $4}''); [ "${free:-0}" -gt 10240 ] || exit 75; i=0; while [ $i -lt 400 ]; do i=$((i+1)); QUERY_STRING=''action=trace'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done'
          if ($result.ExitCode -ne 0) { throw "rotation boundary guard failed: $($result.Output)" }
        }
      }
    }
    'delivery_profile' {
      $destination = Join-Path $runRoot 'outbox'
      switch ($Case.delivery_profile) {
        'normal' { [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1'); if (-not $DryRun) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -OpalAddress $OpalAddress -DestinationDirectory $destination -Once } }
        'backlog_recovery' { [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1; /usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1'); if (-not $DryRun) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -OpalAddress $OpalAddress -DestinationDirectory $destination -Once } }
        'puller_restart' {
          if (-not $DryRun) {
            $lock = Join-Path $destination '.pull.lock'; [IO.Directory]::CreateDirectory($lock) | Out-Null; Set-Content -LiteralPath (Join-Path $lock 'pid') -Value '999999' -Encoding ascii
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -OpalAddress $OpalAddress -DestinationDirectory $destination -Once
          }
        }
      }
      if (-not $DryRun -and $LASTEXITCODE -ne 0) { throw 'outbox pull failed' }
    }
    'ordered_race' {
      if ($Case.case_type -ne 'ordered_race') { return }
      switch ($Case.case_id) {
        'RACE-01' {
          [void](Invoke-Remote '(QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1) & sleep 1; p=$(pidof ddserver | awk ''{print $1}''); [ -n "$p" ] && kill "$p"; wait')
          [void](Wait-Healthy); Invoke-StatusProbe $trace
        }
        'RACE-02' {
          [void](Invoke-Remote 'p=$(pidof ddserver | awk ''{print $1}''); [ -n "$p" ] && kill "$p"; QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1 || true')
          [void](Wait-Healthy); Invoke-StatusProbe $trace
        }
        'RACE-03' {
          [void](Invoke-Remote '(i=0; while [ $i -lt 12 ]; do i=$((i+1)); QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done) & sleep 1; p=$(cat /tmp/d810-bridge-v21.pid); [ -n "$p" ] && kill "$p"; wait')
          [void](Wait-Healthy)
        }
        'RACE-04' {
          [void](Invoke-Remote 'p=$(cat /tmp/d810-bridge-v21.pid); [ -n "$p" ] && kill "$p"; sleep 4; QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1')
          [void](Wait-Healthy)
        }
        'RACE-05' {
          [void](Invoke-Remote 'p=$(cat /tmp/d810-bridge-v21.pid); [ -n "$p" ] && kill "$p"; QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1 || true')
          [void](Wait-Healthy)
        }
        'RACE-06' {
          [void](Invoke-Remote '(QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1) & p=$(cat /tmp/d810-bridge-v21.pid); [ -n "$p" ] && kill "$p"; wait')
          [void](Wait-Healthy)
        }
        'RACE-07' {
          Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1')
          [void](Invoke-Remote 'touch /tmp/d810-session.live /tmp/d810-session.repair; sleep 4; rm -f /tmp/d810-session.live')
          [void](Wait-Healthy)
        }
        'RACE-08' {
          [void](Invoke-Remote 'touch /tmp/d810-session.live /tmp/d810-session.repair; sleep 4; rm -f /tmp/d810-session.live')
          Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1'); [void](Wait-Healthy)
        }
        'RACE-09' {
          [void](Invoke-Remote 'touch /tmp/d810-session.live /tmp/d810-session.repair; sleep 1')
          Invoke-Adb @('shell','monkey','-p','com.example.underlab_camera','1')
          [void](Invoke-Remote 'sleep 3; rm -f /tmp/d810-session.live'); [void](Wait-Healthy)
        }
        'RACE-10' {
          [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1 & sleep 1; reboot -f')
          if (-not $DryRun) { Start-Sleep -Seconds 8 }; [void](Wait-Healthy)
          [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1')
        }
        'RACE-11' {
          if (-not $DryRun) {
            [void](Invoke-Remote '/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1')
            $destination = Join-Path $runRoot 'race-outbox'
            $process = Start-Process -WindowStyle Hidden -PassThru -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$puller,'-OpalAddress',$OpalAddress,'-DestinationDirectory',$destination,'-Once')
            Start-Sleep -Seconds 1
            if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -OpalAddress $OpalAddress -DestinationDirectory $destination -Once
            if ($LASTEXITCODE -ne 0) { throw 'puller retry failed' }
          }
        }
        'RACE-12' {
          [void](Invoke-Remote '(i=0; while [ $i -lt 400 ]; do i=$((i+1)); QUERY_STRING=''action=trace'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done) & /usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1; wait')
        }
        default { throw "Unknown ordered race: $($Case.case_id)" }
      }
    }
    'final_assert' {
      [void](Invoke-Remote "QUERY_STRING='action=live-off' /www/cgi-bin/action-v21 >/dev/null 2>&1; /usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1")
      if (-not $DryRun) {
        $destination = Join-Path $runRoot 'outbox'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -OpalAddress $OpalAddress -DestinationDirectory $destination -Once
        if ($LASTEXITCODE -ne 0) { throw 'final outbox pull failed' }
        $remainingReady = Get-OutboxReadyCount
        if ($remainingReady -gt $MaxResidualReady) { throw "final outbox residual exceeds limit: ready=$remainingReady limit=$MaxResidualReady" }
      }
      [void](Wait-Healthy)
    }
    default { throw "Unknown stage: $Stage" }
  }
}

$rows = @(Import-Csv -LiteralPath $suiteResolved)
if ($script:state.PSObject.Properties.Name -notcontains 'totalRows') { $script:state | Add-Member -NotePropertyName totalRows -NotePropertyValue $rows.Count }
else { $script:state.totalRows = $rows.Count }
if ($script:state.PSObject.Properties.Name -notcontains 'unattended') { $script:state | Add-Member -NotePropertyName unattended -NotePropertyValue ([bool]$Unattended) }
else { $script:state.unattended = [bool]$Unattended }
Save-State
$processedThisInvocation = 0
$waiting = $false
$safetyStopped = $false
$consecutiveFailures = 0
try {
  $script:state.status = if ($DryRun) { 'DRYRUN' } else { 'RUNNING' }
  $script:state.waitingReason = ''
  Save-State
  Write-Event 'run_opened' '' '' $script:state.status "suiteRows=$($rows.Count) suiteHash=$suiteHash"

  foreach ($case in $rows) {
    if ($MaxCases -gt 0 -and $processedThisInvocation -ge $MaxCases) { break }
    $casePath = Join-Path $casesRoot "$($case.case_id).json"
    if (Test-Path -LiteralPath $casePath) { continue }

    if ($script:state.currentCase -ne $case.case_id) {
      $script:state.currentCase = $case.case_id
      $script:state.nextStage = 0
      Save-State
    }

    $startedAt = (Get-Date).ToString('o')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
      for ($stageIndex = [int]$script:state.nextStage; $stageIndex -lt $stages.Count; $stageIndex++) {
        $stageName = $stages[$stageIndex]
        if ($stageName -ne 'delivery_profile') { Require-StorageSafety $case.case_id $stageName }
        Write-Event 'stage_started' $case.case_id $stageName 'START'
        Invoke-Stage $case $stageName
        $script:state.nextStage = $stageIndex + 1
        Save-State
        Write-Event 'stage_completed' $case.case_id $stageName 'PASS'
      }
      $watch.Stop()
      $caseResult = [ordered]@{ caseId=$case.case_id; result='PASS'; startedAt=$startedAt; completedAt=(Get-Date).ToString('o'); durationMs=$watch.ElapsedMilliseconds; lastStage=$stages[-1] }
      Write-AtomicJson $casePath $caseResult
      $script:state.completed = [int]$script:state.completed + 1
      $script:state.passed = [int]$script:state.passed + 1
      $script:state.currentCase = ''
      $script:state.nextStage = 0
      Save-State
      Write-Event 'case_completed' $case.case_id '' 'PASS' "durationMs=$($watch.ElapsedMilliseconds)"
      $processedThisInvocation++
      $consecutiveFailures = 0
    } catch [System.OperationCanceledException] {
      $waiting = $true
      break
    } catch {
      $watch.Stop()
      $failureMessage = $_.Exception.Message
      $failureStage = $stages[[Math]::Min([int]$script:state.nextStage,$stages.Count - 1)]
      if ($Unattended) {
        $caseResult = [ordered]@{ caseId=$case.case_id; result='FAIL'; startedAt=$startedAt; completedAt=(Get-Date).ToString('o'); durationMs=$watch.ElapsedMilliseconds; lastStage=$failureStage; detail=$failureMessage }
        Write-AtomicJson $casePath $caseResult
        $script:state.completed = [int]$script:state.completed + 1
        $script:state.failed = [int]$script:state.failed + 1
        $script:state.currentCase = ''
        $script:state.nextStage = 0
        $script:state.waitingReason = $failureMessage
        Save-State
        Write-Event 'case_failed' $case.case_id $failureStage 'FAIL' $failureMessage
        $processedThisInvocation++
        $consecutiveFailures++
        if ($consecutiveFailures -ge $MaxConsecutiveFailures) {
          $script:state.status = 'SAFETY_STOPPED'
          $script:state.waitingReason = "consecutive failure limit reached: $consecutiveFailures"
          Save-State
          Write-Event 'safety_stop' $case.case_id $failureStage 'SAFETY_STOPPED' $script:state.waitingReason
          $safetyStopped = $true
          break
        }
      } else {
        $script:state.status = 'FAILED'
        $script:state.failed = [int]$script:state.failed + 1
        $script:state.waitingReason = $failureMessage
        Save-State
        Write-Event 'case_failed' $case.case_id $failureStage 'FAIL' $failureMessage
        throw
      }
    }
  }

  if (-not $waiting -and -not $safetyStopped) {
    $remaining = @($rows | Where-Object { -not (Test-Path -LiteralPath (Join-Path $casesRoot "$($_.case_id).json")) }).Count
    $script:state.status = if ($remaining -eq 0 -and [int]$script:state.failed -gt 0) { 'COMPLETED_WITH_FAILURES' } elseif ($remaining -eq 0) { 'COMPLETED' } else { 'PAUSED' }
    Save-State
    Write-Event 'run_closed' '' '' $script:state.status "completed=$($script:state.completed) remaining=$remaining"
  }
} finally {
  $owner = Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($owner -eq "$PID") { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}

Write-Output "RUN_ID=$RunId"
Write-Output "STATE=$statePath"
Write-Output "STATUS=$($script:state.status) completed=$($script:state.completed) passed=$($script:state.passed) failed=$($script:state.failed)"
if ($waiting) { exit 2 }
