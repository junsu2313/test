param(
  [string]$RunId = 'pipeline-auto92-seed810-20260815',
  [int]$RefreshSeconds = 1
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runRoot = Join-Path $repoRoot "chaos-results\pipeline-suite\$RunId"
$statePath = Join-Path $runRoot 'state.json'
$eventsPath = Join-Path $runRoot 'events.jsonl'

$stages = @(
  [pscustomobject]@{ Name='preflight'; Label='Preflight'; Group='ENVIRONMENT' },
  [pscustomobject]@{ Name='d810'; Label='D810 state'; Group='CAMERA' },
  [pscustomobject]@{ Name='ddserver'; Label='ddserver'; Group='TRANSFER' },
  [pscustomobject]@{ Name='session_manager'; Label='Session manager'; Group='SESSION' },
  [pscustomobject]@{ Name='s10'; Label='S10 client'; Group='CLIENT' },
  [pscustomobject]@{ Name='operating_mode'; Label='Feature / Live view'; Group='FEATURE' },
  [pscustomobject]@{ Name='log_profile'; Label='Log collection'; Group='OBSERVE' },
  [pscustomobject]@{ Name='delivery_profile'; Label='Outbox delivery'; Group='STORAGE' },
  [pscustomobject]@{ Name='ordered_race'; Label='Ordered race'; Group='RACE' },
  [pscustomobject]@{ Name='final_assert'; Label='Final assertion'; Group='VERIFY' }
)

function Write-ColorLine {
  param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray)
  Write-Host $Text -ForegroundColor $Color
}

function Read-State {
  try { return Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json }
  catch { return $null }
}

function Read-Events {
  if (-not (Test-Path -LiteralPath $eventsPath)) { return @() }
  try {
    $stream = [IO.File]::Open($eventsPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
      $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
      try { $lines = @($reader.ReadToEnd() -split "`r?`n" | Select-Object -Last 300) }
      finally { $reader.Dispose() }
    } catch {
      $stream.Dispose()
      throw
    }
  } catch { return @() }
  $result = @()
  foreach ($line in $lines) {
    try { $result += ($line | ConvertFrom-Json) } catch { }
  }
  return $result
}

function Event-Color {
  param($Event)
  $combined = "$($Event.result) $($Event.event) $($Event.detail)"
  if ($combined -match '(?i)FAIL|FAILED|ABORT|battery|low battery|storage|safety') { return [ConsoleColor]::Red }
  if ($combined -match '(?i)PASS|completed') { return [ConsoleColor]::Green }
  if ($combined -match '(?i)WAIT|PAUSED') { return [ConsoleColor]::Yellow }
  return [ConsoleColor]::DarkGray
}

$Host.UI.RawUI.WindowTitle = 'D810 Chaos Pipeline Live'
while ($true) {
  $state = Read-State
  $events = Read-Events
  Clear-Host
  Write-ColorLine 'D810 CHAOS PIPELINE - LIVE' Cyan
  Write-ColorLine ('=' * 76) DarkGray

  if (-not $state) {
    Write-ColorLine "Waiting for state file: $statePath" Yellow
    Start-Sleep -Seconds $RefreshSeconds
    continue
  }

  $currentCase = if ($state.currentCase) { $state.currentCase } else { '-' }
  $currentIndex = [Math]::Min([int]$state.nextStage, $stages.Count - 1)
  $currentStage = if ($state.currentCase) { $stages[$currentIndex] } else { $null }
  $statusColor = switch -Regex ($state.status) {
    'FAILED|ABORT|SAFETY|COMPLETED_WITH_FAILURES' { [ConsoleColor]::Red; break }
    'WAIT|PAUSED' { [ConsoleColor]::Yellow; break }
    'RUNNING' { [ConsoleColor]::Cyan; break }
    'COMPLETED' { [ConsoleColor]::Green; break }
    default { [ConsoleColor]::Gray }
  }

  Write-ColorLine ("CURRENT CASE : {0}" -f $currentCase) White
  if ($currentStage) {
    Write-ColorLine ("CURRENT STAGE: {0}  /  {1}" -f $currentStage.Label,$currentStage.Group) Cyan
  } else {
    Write-ColorLine 'CURRENT STAGE: Waiting for next case' DarkGray
  }
  $totalRows = if ($state.totalRows) { $state.totalRows } else { 92 }
  Write-ColorLine ("PROGRESS     : {0}/{1}  |  PASS {2}  |  FAIL {3}" -f $state.completed,$totalRows,$state.passed,$state.failed) $statusColor
  Write-ColorLine ("STATUS       : {0}" -f $state.status) $statusColor
  if ($state.waitingReason) { Write-ColorLine ("REASON       : {0}" -f $state.waitingReason) $statusColor }

  Write-Host ''
  Write-ColorLine 'STAGE PROGRESS' White
  Write-ColorLine ('-' * 76) DarkGray
  $caseEvents = @($events | Where-Object { $_.caseId -eq $state.currentCase })
  foreach ($index in 0..($stages.Count - 1)) {
    $stage = $stages[$index]
    $completion = $caseEvents | Where-Object { $_.stage -eq $stage.Name -and $_.event -eq 'stage_completed' } | Select-Object -Last 1
    $failure = $caseEvents | Where-Object { $_.stage -eq $stage.Name -and $_.event -match 'failed|safety_wait' } | Select-Object -Last 1
    if ($failure) {
      Write-ColorLine ("  X  [{0,-10}] {1}" -f $stage.Group,$stage.Label) Red
    } elseif ($completion) {
      Write-ColorLine ("  OK [{0,-10}] {1}" -f $stage.Group,$stage.Label) Green
    } elseif ($state.currentCase -and $index -eq $currentIndex) {
      Write-ColorLine ("  >> [{0,-11}] {1}  RUNNING" -f $stage.Group,$stage.Label) Cyan
    } else {
      Write-ColorLine ("  -- [{0,-10}] {1}" -f $stage.Group,$stage.Label) DarkGray
    }
  }

  Write-Host ''
  Write-ColorLine 'RECENT RESULTS' White
  Write-ColorLine ('-' * 76) DarkGray
  $recent = @($events | Where-Object { $_.event -match 'case_completed|case_failed|manual_wait|safety_wait' } | Select-Object -Last 6)
  if ($recent.Count -eq 0) { Write-ColorLine '  No completed results yet' DarkGray }
  foreach ($event in $recent) {
    $time = try { ([datetime]$event.at).ToString('HH:mm:ss') } catch { '--:--:--' }
    $detail = if ($event.detail) { " - $($event.detail)" } else { '' }
    Write-ColorLine ("  {0}  {1,-10} {2,-8}{3}" -f $time,$event.caseId,$event.result,$detail) (Event-Color $event)
  }

  Write-Host ''
  Write-ColorLine 'Ctrl+C closes this watcher only; the test keeps running.' DarkGray
  Start-Sleep -Seconds ([Math]::Max(1,$RefreshSeconds))
}
