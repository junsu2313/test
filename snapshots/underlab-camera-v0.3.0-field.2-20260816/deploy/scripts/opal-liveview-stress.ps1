param(
  [string]$HostName = '192.168.8.1',
  [string]$User = 'root',
  [Parameter(Mandatory = $true)]
  [string]$Password,
  [string]$HostKey = 'SHA256:qVZ0SCtT4uBHJXGyLdwEnK/fZwZjl4pXvk/y8zIeCQY',
  [int]$StatusIterations = 20,
  [int]$CommandTimeoutMs = 12000
)

$ErrorActionPreference = 'Stop'

$plink = (Get-Command plink.exe -ErrorAction Stop).Source
$script:Results = [System.Collections.Generic.List[object]]::new()

function Invoke-Remote {
  param([Parameter(Mandatory = $true)][string]$Command)
  $output = & $plink -batch -ssh -hostkey $HostKey -l $User -pw $Password $HostName $Command 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  [pscustomobject]@{
    ExitCode = $exitCode
    Output = $output
    Error = ''
    TimedOut = $exitCode -eq 124
  }
}

function Record-Result {
  param([string]$Name, [bool]$Passed, [string]$Detail)
  $script:Results.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
  $state = if ($Passed) { 'PASS' } else { 'FAIL' }
  Write-Output "$state $Name $Detail"
}

function Get-Status {
  $result = Invoke-Remote 'wget -T 6 -qO- http://127.0.0.1/cgi-bin/status-v21'
  $data = $null
  try { $data = $result.Output.Trim() | ConvertFrom-Json } catch {}
  $ok = $result.ExitCode -eq 0 -and $null -ne $data -and $data.ok -eq $true -and $data.cameraDetected -eq $true
  return [pscustomobject]@{ Passed = $ok; Data = $data; Output = $result.Output; Error = $result.Error; TimedOut = $result.TimedOut }
}

function Run-StatusBurst {
  param([string]$Name)
  $passed = 0
  for ($i = 1; $i -le $StatusIterations; $i++) {
    $status = Get-Status
    if ($status.Passed) { $passed++ }
  }
  $ok = $passed -eq $StatusIterations
  Record-Result $Name $ok "success=$passed/$StatusIterations"
}

function Run-LiveStatusBurst {
  param([string]$Name)
  $passed = 0
  $frameIds = [System.Collections.Generic.List[long]]::new()
  for ($i = 1; $i -le $StatusIterations; $i++) {
    $status = Get-Status
    $fresh = $status.Passed -and $status.Data.liveView -eq $true -and
      $status.Data.backendState -eq 'live' -and [long]$status.Data.frameAgeMs -lt 2000
    if ($fresh) {
      $passed++
      $frameIds.Add([long]$status.Data.frameId)
    }
    Start-Sleep -Milliseconds 250
  }
  $advanced = $frameIds.Count -ge 2 -and $frameIds[$frameIds.Count - 1] -gt $frameIds[0]
  $ok = $passed -eq $StatusIterations -and $advanced
  Record-Result $Name $ok "fresh=$passed/$StatusIterations frameIds=$($frameIds -join ',')"
}

function Stop-RemoteProcess {
  param([string]$Name, [string]$Pattern)
  $command = 'pid=$(ps | grep {0} | grep -v grep | head -n 1 | cut -c1-5); [ -n "$pid" ] && kill $pid; echo killed_pid=$pid' -f $Pattern
  $result = Invoke-Remote $command
  $ok = $result.ExitCode -eq 0 -and $result.Output -match 'killed_pid=\s*[0-9]+'
  Record-Result $Name $ok (($result.Output + $result.Error).Trim())
}

$initial = Invoke-Remote 'cat /tmp/d810-session-v21.state'
$sessionLine = ($initial.Output -split "`r?`n" | Where-Object { $_ -like 'sessionId=*' } | Select-Object -First 1)
$sessionId = if ($sessionLine) { ($sessionLine -split '=', 2)[1] } else { '' }
if ($initial.ExitCode -ne 0 -or -not $sessionId) {
  throw "Unable to determine the active session without starting a new one."
}
Write-Output "FIXED_SESSION $sessionId"

try {
  $liveOn = Invoke-Remote 'wget -T 12 -qO- http://127.0.0.1/cgi-bin/action-v21?action=live-on'
  Record-Result 'live-on' ($liveOn.ExitCode -eq 0 -and $liveOn.Output -match '"status":"liveview_on"') $liveOn.Output.Trim()

  Run-LiveStatusBurst 'baseline-liveview'

  Stop-RemoteProcess 'inject-websocket-fault' 'd810ws.lua'
  Start-Sleep -Seconds 8
  Run-LiveStatusBurst 'after-websocket-recovery'

  Stop-RemoteProcess 'inject-bridge-fault' 'd810bridge.lua'
  Start-Sleep -Seconds 20
  Run-LiveStatusBurst 'after-bridge-recovery'

  Stop-RemoteProcess 'inject-ddserver-fault' 'ddserver'
  Start-Sleep -Seconds 15
  Run-LiveStatusBurst 'after-ddserver-recovery'

  $finalStatus = Get-Status
  $sessionPreserved = $finalStatus.Passed -and $finalStatus.Data.liveView -eq $true -and
    [string]$finalStatus.Data.sessionId -eq $sessionId -and [long]$finalStatus.Data.frameAgeMs -lt 2000
  Record-Result 'fixed-session-preserved' $sessionPreserved $finalStatus.Output.Trim()
}
finally {
  [void](Invoke-Remote 'wget -T 12 -qO- http://127.0.0.1/cgi-bin/action-v21?action=live-off')
}

$failed = @($script:Results | Where-Object { -not $_.Passed })
Write-Output "SUMMARY passed=$($script:Results.Count - $failed.Count) failed=$($failed.Count) session=$sessionId"
if ($failed.Count -gt 0) { exit 1 }
