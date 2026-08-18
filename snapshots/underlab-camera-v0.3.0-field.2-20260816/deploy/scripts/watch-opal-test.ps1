param(
  [int]$ExpectedLoops = 20,
  [int]$PollSeconds = 2
)

$ErrorActionPreference = 'Stop'
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
$key = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'artifacts\ssh\opal-tailscale_rsa'
$sshArgs = @('-i',$key,'-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa','root@100.123.59.97')
$seen = 0
$run = ''

while ($true) {
  $remote = 'run=$(cat /root/d810-test-runs/latest); echo RUN=$run; cat /root/d810-test-runs/$run/summary.tsv 2>/dev/null'
  $lines = @(& $ssh @sshArgs $remote 2>$null)
  if ($LASTEXITCODE -eq 0 -and $lines.Count -gt 0) {
    $runLine = $lines | Where-Object { $_ -like 'RUN=*' } | Select-Object -First 1
    if ($runLine) {
      $currentRun = $runLine.Substring(4)
      if ($run -ne $currentRun) {
        $run = $currentRun
        $seen = 0
        Write-Output "RUN=$run"
      }
    }
    $rows = @($lines | Where-Object { $_ -and $_ -notlike 'RUN=*' -and $_ -notlike 'loop`tresult`t*' })
    if ($rows.Count -gt $seen) {
      $rows[$seen..($rows.Count - 1)] | ForEach-Object { Write-Output $_ }
      $seen = $rows.Count
    }
    if ($seen -ge $ExpectedLoops) {
      Write-Output "TEST_FINISHED reason=expected_loops completed=$seen expected=$ExpectedLoops"
      Write-Output '테스트가 끝났습니다.'
      break
    }
    $stopped = @($rows | Where-Object { $_ -match '`tSTOPPED_' })
    if ($stopped.Count -gt 0) {
      Write-Output "TEST_FINISHED reason=runner_stop completed=$seen expected=$ExpectedLoops"
      Write-Output '테스트가 끝났습니다. 중단 사유를 summary.tsv에서 확인하세요.'
      break
    }
  }
  Start-Sleep -Seconds $PollSeconds
}
