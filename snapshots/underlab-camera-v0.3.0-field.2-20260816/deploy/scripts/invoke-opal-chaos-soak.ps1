param(
  [string]$OpalAddress = '192.168.8.1',
  [string]$KeyFile = (Join-Path $PSScriptRoot '..\..\artifacts\ssh\opal-tailscale_rsa'),
  [int]$DurationMinutes = 60,
  [int]$Seed = 810,
  [int]$RecoveryTimeoutSeconds = 75,
  [int]$QuietSeconds = 5,
  [int]$MaxScenarios = 0
)

$ErrorActionPreference = 'Stop'
if ($DurationMinutes -lt 1) { throw 'DurationMinutes must be at least 1' }
if (-not (Test-Path -LiteralPath $KeyFile)) { throw "SSH key not found: $KeyFile" }

$ssh = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$sshOptions = @(
  '-i', $KeyFile,
  '-o', 'HostKeyAlgorithms=+ssh-rsa',
  '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o', 'HostKeyAlias=192.168.8.1',
  '-o', 'BatchMode=yes',
  '-o', 'ConnectTimeout=5',
  '-o', 'ServerAliveInterval=5',
  '-o', 'ServerAliveCountMax=2'
)

$runId = 'chaos-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-seed$Seed"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$artifactRoot = Join-Path $repoRoot 'chaos-results'
$eventsPath = Join-Path $artifactRoot "$runId-events.jsonl"
$summaryPath = Join-Path $artifactRoot "$runId-summary.tsv"
$random = [Random]::new($Seed)
$deadline = (Get-Date).AddMinutes($DurationMinutes)
$script:PassCount = 0
$script:FailCount = 0

function Write-Event {
  param(
    [string]$Event,
    [string]$Scenario = '',
    [string]$Result = '',
    [long]$DurationMs = 0,
    [string]$Detail = ''
  )
  $row = [ordered]@{
    at = (Get-Date).ToString('o')
    runId = $runId
    seed = $Seed
    event = $Event
    scenario = $Scenario
    result = $Result
    durationMs = $DurationMs
    detail = $Detail
  }
  Add-Content -LiteralPath $eventsPath -Value ($row | ConvertTo-Json -Compress) -Encoding utf8
  Write-Output ("{0} {1} {2} {3}" -f $Event, $Scenario, $Result, $Detail).Trim()
}

function Invoke-Remote {
  param([Parameter(Mandatory = $true)][string]$Command)
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $output = @(& $ssh @sshOptions "root@$OpalAddress" $Command 2>&1)
  $exitCode = $LASTEXITCODE
  $watch.Stop()
  [pscustomobject]@{
    ExitCode = $exitCode
    Output = ($output -join "`n")
    DurationMs = $watch.ElapsedMilliseconds
  }
}

function Get-Health {
  $command = @'
alive_pidfile() { p=$(cat "$1" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
http=$(wget -T 6 -qO- http://127.0.0.1/cgi-bin/status-v21 2>/dev/null || true)
alive_pidfile /tmp/d810-bridge-v21.pid && bridge=1 || bridge=0
alive_pidfile /tmp/d810-ws-v21.pid && websocket=1 || websocket=0
alive_pidfile /tmp/d810-runtime-guardian.pid && runtime_guardian=1 || runtime_guardian=0
alive_pidfile /tmp/d810-session-health.pid && session_health=1 || session_health=0
alive_pidfile /tmp/d810-battery-worker.pid && battery_worker=1 || battery_worker=0
pidof ddserver >/dev/null 2>&1 && ddserver=1 || ddserver=0
ps w | grep -q '[u]sr/bin/d810-boot-watch' && boot_watch=1 || boot_watch=0
printf 'bridge=%s websocket=%s runtime_guardian=%s session_health=%s battery_worker=%s ddserver=%s boot_watch=%s\n' "$bridge" "$websocket" "$runtime_guardian" "$session_health" "$battery_worker" "$ddserver" "$boot_watch"
printf 'status=%s\n' "$http"
'@
  $result = Invoke-Remote $command
  $line = ($result.Output -split "`r?`n" | Where-Object { $_ -like 'bridge=*' } | Select-Object -First 1)
  $status = ($result.Output -split "`r?`n" | Where-Object { $_ -like 'status=*' } | Select-Object -First 1)
  $required = @('bridge=1', 'websocket=1', 'runtime_guardian=1', 'session_health=1', 'battery_worker=1', 'ddserver=1', 'boot_watch=1')
  $processesHealthy = $result.ExitCode -eq 0
  foreach ($token in $required) { $processesHealthy = $processesHealthy -and $line.Contains($token) }
  $httpHealthy = $status -match '"ok"\s*:\s*true' -and
    $status -match '"transportReady"\s*:\s*true' -and
    $status -match '"softwareReady"\s*:\s*true' -and
    $status -match '"cameraDetected"\s*:\s*true' -and
    $status -match '"status"\s*:\s*"ready"'
  [pscustomobject]@{
    Healthy = $processesHealthy -and $httpHealthy
    ProcessesHealthy = $processesHealthy
    HttpHealthy = $httpHealthy
    Detail = (($line, $status) -join ' ').Trim()
  }
}

function Invoke-GuardAction {
  param([string]$Trace)
  Invoke-Remote "HTTP_X_D810_TRACE='$Trace' HTTP_X_D810_COMMAND_ID='$Trace-1' HTTP_X_D810_CLIENT='chaos-soak' QUERY_STRING='action=manual-status' /www/cgi-bin/action-v21 >/dev/null 2>&1"
}

function Wait-Recovery {
  param([string]$Scenario, [string]$Trace)
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $passiveDeadline = (Get-Date).AddSeconds([Math]::Min(15, $RecoveryTimeoutSeconds))
  $actionTriggered = $false
  do {
    $health = Get-Health
    if ($health.Healthy) {
      $watch.Stop()
      return [pscustomobject]@{ Passed = $true; DurationMs = $watch.ElapsedMilliseconds; Mode = $(if ($actionTriggered) { 'action' } else { 'passive' }); Detail = $health.Detail }
    }
    if (-not $actionTriggered -and (Get-Date) -ge $passiveDeadline) {
      [void](Invoke-GuardAction $Trace)
      $actionTriggered = $true
    }
    Start-Sleep -Seconds 2
  } while ($watch.Elapsed.TotalSeconds -lt $RecoveryTimeoutSeconds)
  $watch.Stop()
  [pscustomobject]@{ Passed = $false; DurationMs = $watch.ElapsedMilliseconds; Mode = $(if ($actionTriggered) { 'action' } else { 'passive' }); Detail = $health.Detail }
}

function Invoke-Fault {
  param([string]$Scenario, [string]$Trace)
  switch ($Scenario) {
    'trace_burst' {
      $command = 'i=0; while [ $i -lt 40 ]; do i=$((i+1)); HTTP_X_D810_TRACE=''__TRACE__'' HTTP_X_D810_COMMAND_ID=''__TRACE__-''$i HTTP_X_D810_CLIENT=''chaos-soak'' QUERY_STRING=''action=trace'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done'
      return Invoke-Remote ($command.Replace('__TRACE__', $Trace))
    }
    'checkpoint_race' {
      return Invoke-Remote 'i=0; while [ $i -lt 6 ]; do i=$((i+1)); /usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1 & done; wait; find /root/d810-outbox -maxdepth 1 -type f -name ''*.ready'' | wc -l'
    }
    'bridge_term' {
      return Invoke-Remote 'p=$(cat /tmp/d810-bridge-v21.pid 2>/dev/null); [ -n "$p" ] && kill "$p"; echo pid=$p'
    }
    'websocket_term' {
      return Invoke-Remote 'p=$(cat /tmp/d810-ws-v21.pid 2>/dev/null); [ -n "$p" ] && kill "$p"; echo pid=$p'
    }
    'ddserver_term' {
      return Invoke-Remote 'p=$(pidof ddserver 2>/dev/null | awk ''{print $1}''); [ -n "$p" ] && kill "$p"; echo pid=$p'
    }
    'runtime_guardian_term' {
      return Invoke-Remote 'p=$(cat /tmp/d810-runtime-guardian.pid 2>/dev/null); [ -n "$p" ] && kill "$p"; echo pid=$p'
    }
    'bridge_websocket_term' {
      return Invoke-Remote 'a=$(cat /tmp/d810-bridge-v21.pid 2>/dev/null); b=$(cat /tmp/d810-ws-v21.pid 2>/dev/null); [ -n "$a" ] && kill "$a"; [ -n "$b" ] && kill "$b"; echo bridge=$a websocket=$b'
    }
    'bridge_ddserver_term' {
      return Invoke-Remote 'a=$(cat /tmp/d810-bridge-v21.pid 2>/dev/null); b=$(pidof ddserver 2>/dev/null | awk ''{print $1}''); [ -n "$a" ] && kill "$a"; [ -n "$b" ] && kill "$b"; echo bridge=$a ddserver=$b'
    }
    'action_bridge_race' {
      $command = '(i=0; while [ $i -lt 12 ]; do i=$((i+1)); HTTP_X_D810_TRACE=''__TRACE__'' HTTP_X_D810_COMMAND_ID=''__TRACE__-''$i HTTP_X_D810_CLIENT=''chaos-soak'' QUERY_STRING=''action=manual-status'' /www/cgi-bin/action-v21 >/dev/null 2>&1; done) & sleep 1; p=$(cat /tmp/d810-bridge-v21.pid 2>/dev/null); [ -n "$p" ] && kill "$p"; wait; echo bridge=$p'
      return Invoke-Remote ($command.Replace('__TRACE__', $Trace))
    }
    default { throw "Unknown scenario: $Scenario" }
  }
}

$scenarios = @(
  'trace_burst',
  'checkpoint_race',
  'bridge_term',
  'websocket_term',
  'ddserver_term',
  'runtime_guardian_term',
  'bridge_websocket_term',
  'bridge_ddserver_term',
  'action_bridge_race'
)

"scenario`tresult`trecovery_ms`trecovery_mode`tdetail" | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Event 'run_started' '' 'START' 0 "durationMinutes=$DurationMinutes scenarios=$($scenarios.Count)"

$baseline = Get-Health
if (-not $baseline.Healthy) {
  Write-Event 'preflight' '' 'FAIL' 0 $baseline.Detail
  throw "Opal baseline is not healthy: $($baseline.Detail)"
}
Write-Event 'preflight' '' 'PASS' 0 $baseline.Detail

$round = 0
while ((Get-Date) -lt $deadline -and ($MaxScenarios -eq 0 -or $round -lt $MaxScenarios)) {
  $round++
  $scenario = $scenarios[$random.Next(0, $scenarios.Count)]
  $trace = "$runId-r$round-$scenario"
  Write-Event 'fault_started' $scenario 'START' 0 "trace=$trace round=$round"
  $fault = Invoke-Fault $scenario $trace
  Write-Event 'fault_injected' $scenario $(if ($fault.ExitCode -eq 0) { 'PASS' } else { 'FAIL' }) $fault.DurationMs $fault.Output
  $recovery = Wait-Recovery $scenario $trace
  $result = if ($fault.ExitCode -eq 0 -and $recovery.Passed) { 'PASS' } else { 'FAIL' }
  if ($result -eq 'PASS') { $script:PassCount++ } else { $script:FailCount++ }
  "$scenario`t$result`t$($recovery.DurationMs)`t$($recovery.Mode)`t$($recovery.Detail.Replace("`t", ' '))" | Add-Content -LiteralPath $summaryPath -Encoding utf8
  Write-Event 'scenario_completed' $scenario $result $recovery.DurationMs "mode=$($recovery.Mode) $($recovery.Detail)"
  [void](Invoke-Remote "/usr/bin/d810-log-checkpoint periodic >/dev/null 2>&1 || true")
  if ((Get-Date) -lt $deadline) { Start-Sleep -Seconds $QuietSeconds }
}

Write-Event 'run_completed' '' $(if ($script:FailCount -eq 0) { 'PASS' } else { 'FAIL' }) 0 "passed=$script:PassCount failed=$script:FailCount rounds=$round"
Write-Output "RUN_ID=$runId"
Write-Output "ARTIFACTS=$artifactRoot"
Write-Output "SUMMARY passed=$script:PassCount failed=$script:FailCount rounds=$round"
if ($script:FailCount -gt 0) { exit 1 }
