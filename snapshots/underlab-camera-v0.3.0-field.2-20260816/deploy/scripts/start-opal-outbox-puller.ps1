param(
  [int]$IntervalSeconds = 30,
  [int]$MaxItemsPerCycle = 5
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'watch-opal-outbox-puller.ps1'
Start-Process -WindowStyle Hidden -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') `
  -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath,'-IntervalSeconds',"$IntervalSeconds",'-MaxItemsPerCycle',"$MaxItemsPerCycle")
Write-Output 'OUTBOX_PULLER_SUPERVISOR_STARTED'
