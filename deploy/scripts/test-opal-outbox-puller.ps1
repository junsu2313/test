param()

$ErrorActionPreference = 'Stop'
$script = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pull-opal-outbox.ps1') -Raw -Encoding utf8

if ($script -notmatch 'Join-Path \$lock ''pid''') { throw 'puller lock must record an owner pid' }
if ($script -notmatch 'Get-Process -Id') { throw 'puller must detect a live lock owner' }
if ($script -notmatch 'Remove-Item -LiteralPath \$lock -Force -Recurse -ErrorAction (?:Stop|SilentlyContinue)') {
  throw 'puller must recover a stale lock'
}
if ($script -notmatch 'if \(\$owner -eq "\$PID"\)') { throw 'puller must only remove its own lock' }
if ($script -notmatch 'Get-FileHash -Algorithm SHA256|Get-Sha256Hex') { throw 'puller must verify downloaded payloads' }
if ($script -notmatch 'outbox item failed') { throw 'one failed payload must not crash the pull loop' }

Write-Output 'PASS: outbox puller lock ownership and recovery contract'
