param(
  [string]$OpalAddress = '100.123.59.97',
  [string]$DestinationDirectory = (Join-Path $PSScriptRoot '..\..\artifacts\opal-outbox'),
  [string]$KeyFile = (Join-Path $PSScriptRoot '..\..\artifacts\ssh\opal-tailscale_rsa'),
  [int]$IntervalSeconds = 60,
  [int]$MaxItemsPerCycle = 1,
  [bool]$PauseWhenLiveView = $true,
  [string]$TimelinePath = (Join-Path $PSScriptRoot '..\..\artifacts\opal-outbox\pc-transfer-timeline.jsonl'),
  [switch]$Once
)

$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
  param([string]$Path)
  $stream = [IO.File]::OpenRead($Path)
  try {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
  } finally { $stream.Dispose() }
}

$ssh = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$scp = Join-Path $env:WINDIR 'System32\OpenSSH\scp.exe'
if (-not (Test-Path -LiteralPath $ssh)) { throw "ssh not found: $ssh" }
if (-not (Test-Path -LiteralPath $scp)) { throw "scp not found: $scp" }
if (-not (Test-Path -LiteralPath $KeyFile)) { throw "SSH key not found: $KeyFile" }
$sshOptions = @(
  '-o','HostKeyAlgorithms=+ssh-rsa',
  '-o','PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o','BatchMode=yes',
  '-o','HostKeyAlias=192.168.8.1',
  '-o','ConnectTimeout=5',
  '-o','ServerAliveInterval=5',
  '-o','ServerAliveCountMax=2',
  '-i',$KeyFile
)

[System.IO.Directory]::CreateDirectory($DestinationDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $TimelinePath)) | Out-Null
$lock = Join-Path $DestinationDirectory '.pull.lock'
$lockPid = Join-Path $lock 'pid'
$lockOwned = $false
try {
  New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null
  $lockOwned = $true
} catch {
  $owner = if (Test-Path -LiteralPath $lockPid) {
    Get-Content -LiteralPath $lockPid -ErrorAction SilentlyContinue | Select-Object -First 1
  }
  $ownerProcess = if ($owner -match '^\d+$') {
    Get-Process -Id ([int]$owner) -ErrorAction SilentlyContinue
  }
  if ($ownerProcess) { throw "outbox pull worker already running (pid=$owner)" }
  Remove-Item -LiteralPath $lock -Force -Recurse -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null
  $lockOwned = $true
}
Set-Content -LiteralPath $lockPid -Value $PID -Encoding ascii

function Write-TimelineEvent {
  param([hashtable]$Event)
  $row = [ordered]@{
    wall = (Get-Date).ToUniversalTime().ToString('o')
    component = 'pc-log-puller'
  }
  foreach ($key in $Event.Keys) { $row[$key] = $Event[$key] }
  Add-Content -LiteralPath $TimelinePath -Value (($row | ConvertTo-Json -Compress))
}

function Test-RemoteCameraBusy {
  if (-not $PauseWhenLiveView) { return $false }
  # The PC already reaches the Opal over Tailscale HTTP. Avoid spawning an
  # SSH shell for this high-frequency gate; SSH startup was measured at about
  # 2.5 seconds per probe while direct HTTP was below 0.5 seconds.
  $status = (& curl.exe --noproxy '*' --connect-timeout 3 --max-time 5 -sS "http://$OpalAddress/cgi-bin/status-v21" 2>$null | Out-String)
  if (-not $status) {
    # Keep a conservative fallback for deployments where nginx is not exposed
    # on the Tailscale interface yet.
    $status = (& $ssh @sshOptions "root@$OpalAddress" "wget -T 3 -qO- http://127.0.0.1/cgi-bin/status-v21 2>/dev/null" 2>$null | Out-String)
  }
  if (-not $status) { return $true }
  return $status -match '"liveView"\s*:\s*true|"backendState"\s*:\s*"live"|"status"\s*:\s*"liveview_on"'
}

try {
  try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch { }

  while ($true) {
    $cycleWatch = [Diagnostics.Stopwatch]::StartNew()
    if (Test-RemoteCameraBusy) {
      Write-TimelineEvent @{ event = 'scheduler_deferred'; reason = 'camera_busy'; intervalSeconds = $IntervalSeconds }
      if ($Once) { break }
      Start-Sleep -Seconds $IntervalSeconds
      continue
    }
    # Field events are always first. Opal's wall clock can jump backwards on
    # reboot, so filename timestamp ordering alone cannot identify fresh logs.
    $listWatch = [Diagnostics.Stopwatch]::StartNew()
    $readyText = & $ssh @sshOptions "root@$OpalAddress" "find /root/d810-outbox -maxdepth 1 -type f -name '*d810-field-events.jsonl.ready' -print | sort -r; find /root/d810-outbox -maxdepth 1 -type f -name '*.ready' -print | grep -v 'd810-field-events.jsonl.ready$' | sort -r | head -n 200" 2>$null
    $listWatch.Stop()
    $itemsTransferred = 0
    foreach ($ready in @($readyText)) {
      if ($itemsTransferred -ge [Math]::Max(1, $MaxItemsPerCycle)) { break }
      if (-not $ready) { continue }
      $name = [System.IO.Path]::GetFileNameWithoutExtension($ready.Trim())
      if ($name -notmatch '^[A-Za-z0-9._-]+$') { continue }
      $remotePayload = "/root/d810-outbox/$name.payload"
      $remoteManifest = "/root/d810-outbox/$name.manifest"
      $itemStage = Join-Path $DestinationDirectory ".staging-$name-$PID"
      $category = 'misc'
      $itemWatch = [Diagnostics.Stopwatch]::StartNew()
      $manifestWatch = [Diagnostics.Stopwatch]::StartNew()
      try {
        Remove-Item -LiteralPath $itemStage -Force -Recurse -ErrorAction SilentlyContinue
        [System.IO.Directory]::CreateDirectory($itemStage) | Out-Null
        & $scp -O -q @sshOptions "root@$OpalAddress`:$remoteManifest" "root@$OpalAddress`:$remotePayload" $itemStage 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "manifest/payload download failed (exit=$LASTEXITCODE)" }
        $manifestWatch.Stop()
        $manifestProbe = Join-Path $itemStage "$name.manifest"
        $payloadProbe = Join-Path $itemStage "$name.payload"
        if (Test-Path -LiteralPath $manifestProbe) {
          $categoryLine = Get-Content -LiteralPath $manifestProbe -ErrorAction SilentlyContinue |
            Where-Object { $_ -like 'category=*' } | Select-Object -First 1
          if ($categoryLine) { $category = ($categoryLine -replace '^category=', '') }
        }
        if ($category -notmatch '^[A-Za-z0-9._-]+$') { $category = 'misc' }
        $categoryDirectory = Join-Path $DestinationDirectory $category
        [System.IO.Directory]::CreateDirectory($categoryDirectory) | Out-Null
        $localPart = Join-Path $categoryDirectory "$name.payload.part"
        $localPayload = Join-Path $categoryDirectory "$name.payload"
        $localManifest = Join-Path $categoryDirectory "$name.manifest"
        Move-Item -LiteralPath $manifestProbe -Destination $localManifest -Force
        Move-Item -LiteralPath $payloadProbe -Destination $localPart -Force
        $payloadWatch = [Diagnostics.Stopwatch]::StartNew()
        $payloadWatch.Stop()
        if (-not (Test-Path -LiteralPath $localPart)) { throw 'payload download produced no file' }
        Move-Item -LiteralPath $localPart -Destination $localPayload -Force
        $hashWatch = [Diagnostics.Stopwatch]::StartNew()
        $localHash = Get-Sha256Hex $localPayload
        $remoteCleanupCommand = 'remote_hash=$(sha256sum ''' + $remotePayload + ''' 2>/dev/null | awk ''{print $1}''); if [ "$remote_hash" = ''' + $localHash + ''' ]; then rm -f ''' + $remotePayload + ''' ''' + $remoteManifest + ''' ''/root/d810-outbox/' + $name + '.ready''; else exit 42; fi'
        & $ssh @sshOptions "root@$OpalAddress" $remoteCleanupCommand 2>$null | Out-Null
        $remoteCleanupExitCode = $LASTEXITCODE
        $hashWatch.Stop()
        if ($remoteCleanupExitCode -eq 42) { throw 'sha256 mismatch; remote item retained' }
        if ($remoteCleanupExitCode -ne 0) { throw "remote verify/delete failed (exit=$remoteCleanupExitCode)" }
        $deleteWatch = $hashWatch
        Remove-Item -LiteralPath $itemStage -Force -Recurse -ErrorAction SilentlyContinue
        $itemsTransferred++
        $itemWatch.Stop()
        Write-TimelineEvent @{
          event = 'transfer_completed'; item = $name; bytes = (Get-Item -LiteralPath $localPayload).Length
          totalMs = $itemWatch.ElapsedMilliseconds; manifestMs = $manifestWatch.ElapsedMilliseconds
          payloadMs = $payloadWatch.ElapsedMilliseconds; hashVerifyMs = $hashWatch.ElapsedMilliseconds
          remoteDeleteMs = $deleteWatch.ElapsedMilliseconds
        }
      } catch {
        $itemWatch.Stop()
        Write-TimelineEvent @{ event = 'transfer_failed'; item = $name; totalMs = $itemWatch.ElapsedMilliseconds; error = $_.Exception.Message }
        Write-Warning "outbox item failed: $name ($($_.Exception.Message))"
        Remove-Item -LiteralPath $localPart -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $itemStage -Force -Recurse -ErrorAction SilentlyContinue
      }
    }
    $cycleWatch.Stop()
    Write-TimelineEvent @{
      event = 'cycle_completed'; readyCount = @($readyText).Count; transferred = $itemsTransferred
      listMs = $listWatch.ElapsedMilliseconds; totalMs = $cycleWatch.ElapsedMilliseconds
    }
    if ($Once) { break }
    Start-Sleep -Seconds $IntervalSeconds
  }
} finally {
  if ($lockOwned) {
    $owner = Get-Content -LiteralPath $lockPid -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($owner -eq "$PID") {
      Remove-Item -LiteralPath $lock -Force -Recurse -ErrorAction SilentlyContinue
    }
  }
}
