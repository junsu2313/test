$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runner = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'invoke-chaos-pipeline-suite.ps1') -Raw -Encoding utf8
$suite = Get-Content -LiteralPath (Join-Path $root 'docs\chaos-hierarchical-pipeline-suite-seed810.csv') -Raw -Encoding utf8

foreach ($required in @('Write-AtomicJson','suiteHash','nextStage','ResumeLatest','ConfirmManualCase','WAITING','casesRoot','ordered_race','RACE-12','Require-StorageSafety','MinFreeKilobytes','InvalidateCase','preservedResult','Get-OutboxReadyCount','MaxResidualReady','final outbox residual exceeds limit','mdns services','ResolvedS10Serial','Invoke-S10WirelessContinuity','wireless disconnect disabled; continuity probe only','post_power_cycle_recover','post_usb_reconnect','FileShare]::ReadWrite','Unattended','MaxConsecutiveFailures','SAFETY_STOPPED','COMPLETED_WITH_FAILURES','wireless_continuity')) {
  if ($runner -notmatch [regex]::Escape($required)) { throw "runner missing contract: $required" }
}
foreach ($forbidden in @("action=shut" + "ter", "af_sh" + "ot", "action=capt" + "ure")) {
  if ($runner -match [regex]::Escape($forbidden)) { throw "forbidden camera actuation in runner: $forbidden" }
  if ($suite -match [regex]::Escape($forbidden)) { throw "forbidden camera actuation in suite: $forbidden" }
}
if ($runner -notmatch [regex]::Escape("Security.Cryptography.SHA256")) { throw 'suite mutation guard missing' }
if ($runner -notmatch [regex]::Escape("Move-Item -LiteralPath `$temporary")) { throw 'atomic checkpoint replacement missing' }
foreach ($networkCutPattern in @(
  'svc\s+wifi\s+(disable|enable)',
  'ip\s+link\s+set\s+\S+\s+down',
  'ifconfig\s+\S+\s+down',
  'iptables\s+',
  'nft\s+(add|insert|delete|flush)',
  'airplane-mode\s+enable'
)) {
  if ($runner -match $networkCutPattern) { throw "runner must not disrupt Wi-Fi, LAN, or Internet: $networkCutPattern" }
}

Write-Output 'PASS: resumable hierarchy-aware pipeline runner contract'
