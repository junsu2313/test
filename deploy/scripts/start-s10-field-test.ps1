param(
  [int]$Loops = 20,
  [int]$BatteryMinPercent = 10,
  [int]$BatteryQueryIntervalSeconds = 600,
  [int]$OutboxIntervalSeconds = 60,
  [string]$S10Serial = '192.168.8.165:38917',
  [int]$PollSeconds = 2
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
$key = Join-Path $root 'artifacts\ssh\opal-tailscale_rsa'
$smoke = Join-Path $PSScriptRoot 's10-field-ui-test.ps1'
$puller = Join-Path $PSScriptRoot 'start-opal-outbox-puller.ps1'
$sshArgs = @('-i',$key,'-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa','root@100.123.59.97')

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $puller -IntervalSeconds $OutboxIntervalSeconds | Write-Output
$remote = "D810_TEST_CLIENT_MODE=s10 D810_TEST_S10_IP=192.168.8.165 D810_TEST_S10_REQUIRED=0 D810_TEST_BATTERY_MIN_PERCENT=$BatteryMinPercent D810_TEST_BATTERY_QUERY_INTERVAL_SEC=$BatteryQueryIntervalSeconds /usr/bin/d810-camera-loop-runner-s10 $Loops >/root/d810-test-runs/field-s10-launch.log 2>&1 &"
& $ssh @sshArgs $remote
if ($LASTEXITCODE -ne 0) { throw 'Opal S10 field runner failed to start.' }

$run = ''
$seenReady = @{}
$seenRows = 0
while ($true) {
  $probe = 'run=$(cat /root/d810-test-runs/latest); echo RUN=$run; find /root/d810-test-runs/$run/external-client -maxdepth 1 -type f -name ''*.ready'' -print 2>/dev/null | sort; echo SUMMARY; cat /root/d810-test-runs/$run/summary.tsv 2>/dev/null'
  $lines = @(& $ssh @sshArgs $probe 2>$null)
  if ($LASTEXITCODE -eq 0) {
    $runLine = $lines | Where-Object { $_ -like 'RUN=*' } | Select-Object -First 1
    if ($runLine) {
      $currentRun = $runLine.Substring(4)
      if ($currentRun -ne $run) { $run = $currentRun; Write-Output "RUN=$run" }
    }
    $readyFiles = @($lines | Where-Object { $_ -like '*.ready' })
    foreach ($readyFile in $readyFiles) {
      $name = [IO.Path]::GetFileNameWithoutExtension($readyFile.Trim())
      if ($seenReady.ContainsKey($name)) { continue }
      $seenReady[$name] = $true
      $loop = [int]($name -replace '^loop-','')
      Write-Output "S10_LOOP_START loop=$loop"
      $saved = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      $out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $smoke -Serial $S10Serial -FrameWaitSeconds 5 -CaptureWaitSeconds 15 -KeepAwake 2>&1)
      $exit = $LASTEXITCODE
      $ErrorActionPreference = $saved
      $out | ForEach-Object { Write-Output $_ }
      $result = if ($exit -eq 0 -and (($out -join "`n") -match 'S10_FIELD_TEST_COMPLETE')) { 'PASS' } else { 'FAIL' }
      $signal = "printf '%s\n' $result > '/root/d810-test-runs/$run/external-client/loop-$loop.result'"
      & $ssh @sshArgs $signal | Out-Null
      Write-Output "S10_LOOP_FINISHED loop=$loop result=$result"
    }
    $summaryRows = @($lines | Where-Object { $_ -match '^[0-9]+\t' })
    if ($summaryRows.Count -gt $seenRows) {
      $summaryRows[$seenRows..($summaryRows.Count - 1)] | ForEach-Object { Write-Output $_ }
      $seenRows = $summaryRows.Count
    }
    if ($seenRows -ge $Loops -or ($summaryRows | Where-Object { $_ -match '\tSTOPPED_' }).Count -gt 0) {
      Write-Output "TEST_FINISHED completed=$seenRows expected=$Loops"
      Write-Output '테스트가 끝났습니다.'
      break
    }
  }
  Start-Sleep -Seconds $PollSeconds
}
