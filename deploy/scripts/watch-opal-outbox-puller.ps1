param(
  [int]$IntervalSeconds = 30,
  [int]$MaxItemsPerCycle = 5,
  [int]$RestartDelaySeconds = 10
)

$ErrorActionPreference = 'Stop'
$puller = Join-Path $PSScriptRoot 'pull-opal-outbox.ps1'
$mutexCreated = $false
$mutex = New-Object System.Threading.Mutex($false, 'Local\D810OpalOutboxSupervisor', [ref]$mutexCreated)
if (-not $mutexCreated) {
  $mutex.Dispose()
  exit 0
}

try {
  while ($true) {
    try {
      & (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') `
        -NoProfile -ExecutionPolicy Bypass -File $puller `
        -IntervalSeconds $IntervalSeconds -MaxItemsPerCycle $MaxItemsPerCycle
    } catch {
      try {
        $timeline = Join-Path $PSScriptRoot '..\..\artifacts\opal-outbox\pc-transfer-timeline.jsonl'
        $row = [ordered]@{
          wall = (Get-Date).ToUniversalTime().ToString('o')
          component = 'pc-log-puller-supervisor'
          event = 'worker_restart'
          error = $_.Exception.Message
          restartDelaySeconds = $RestartDelaySeconds
        }
        Add-Content -LiteralPath $timeline -Value (($row | ConvertTo-Json -Compress))
      } catch { }
    }
    Start-Sleep -Seconds ([Math]::Max(3, $RestartDelaySeconds))
  }
} finally {
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
