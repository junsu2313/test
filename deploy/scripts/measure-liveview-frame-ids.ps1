param(
  [string]$WebSocketUrl = 'ws://100.123.59.97:8191/',
  [int]$DurationSeconds = 60,
  [string]$Label = 'idle',
  [string]$OutputDirectory = ''
)

$pythonMonitor = Join-Path $PSScriptRoot 'measure-liveview-frame-ids.py'
$pythonArgs = @($pythonMonitor, '--url', $WebSocketUrl, '--duration', $DurationSeconds, '--label', $Label)
if ($OutputDirectory) { $pythonArgs += @('--output-dir', $OutputDirectory) }
& python @pythonArgs
exit $LASTEXITCODE

$ErrorActionPreference = 'Stop'
if (-not $OutputDirectory) {
  $OutputDirectory = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'artifacts\frame-id'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path $OutputDirectory "$stamp-$Label.csv"
$summaryPath = Join-Path $OutputDirectory "$stamp-$Label-summary.json"

function Read-U32BE([byte[]]$bytes, [int]$offset) {
  return [uint64]$bytes[$offset] * 16777216 + [uint64]$bytes[$offset + 1] * 65536 +
    [uint64]$bytes[$offset + 2] * 256 + [uint64]$bytes[$offset + 3]
}

function Read-U64BE([byte[]]$bytes, [int]$offset) {
  return (Read-U32BE $bytes $offset) * 4294967296 + (Read-U32BE $bytes ($offset + 4))
}

function Get-Percentile([double[]]$values, [double]$ratio) {
  if ($values.Count -eq 0) { return 0 }
  $sorted = @($values | Sort-Object)
  $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, [Math]::Ceiling($sorted.Count * $ratio) - 1))
  return [double]$sorted[$index]
}

$socket = [System.Net.WebSockets.ClientWebSocket]::new()
$socket.Options.SetRequestHeader('X-D810-Client', 'pc-frame-id-monitor')
$cancel = [Threading.CancellationTokenSource]::new()
$cancel.CancelAfter(($DurationSeconds + 8) * 1000)
$socket.ConnectAsync([Uri]$WebSocketUrl, $cancel.Token).GetAwaiter().GetResult()
$watch = [Diagnostics.Stopwatch]::StartNew()
$buffer = New-Object byte[] 65536
$records = [Collections.Generic.List[object]]::new()
$pendingMeta = $null
$previousId = 0
$previousReceiveMs = $null
$previousCaptureDoneAt = $null

try {
  while ($watch.Elapsed.TotalSeconds -lt $DurationSeconds -and
      $socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
    $stream = [IO.MemoryStream]::new()
    do {
      $segment = [ArraySegment[byte]]::new($buffer)
      $result = $socket.ReceiveAsync($segment, $cancel.Token).GetAwaiter().GetResult()
      if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { break }
      $stream.Write($buffer, 0, $result.Count)
    } while (-not $result.EndOfMessage)
    if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { break }
    $payload = $stream.ToArray()
    if ($payload.Length -eq 52 -and [Text.Encoding]::ASCII.GetString($payload, 0, 4) -eq 'D8L5') {
      $pendingMeta = [pscustomobject]@{
        FrameId = [long](Read-U32BE $payload 8)
        StartedAt = [double](Read-U64BE $payload 12)
        CaptureDoneAt = [double](Read-U64BE $payload 20)
        TotalMs = [long](Read-U32BE $payload 28)
        CaptureMs = [long](Read-U32BE $payload 32)
        Bytes = [long](Read-U32BE $payload 36)
      }
      continue
    }
    if ($payload.Length -lt 4 -or $null -eq $pendingMeta) { continue }
    if ($payload[0] -ne 0xff -or $payload[1] -ne 0xd8) { continue }
    $receivedMs = $watch.Elapsed.TotalMilliseconds
    $receiveGap = if ($null -eq $previousReceiveMs) { 0 } else { $receivedMs - $previousReceiveMs }
    $producerGap = if ($null -eq $previousCaptureDoneAt) { 0 } else { $pendingMeta.CaptureDoneAt - $previousCaptureDoneAt }
    $idGap = if ($previousId -gt 0) { [Math]::Max(0, $pendingMeta.FrameId - $previousId - 1) } else { 0 }
    $records.Add([pscustomobject]@{
      FrameId = $pendingMeta.FrameId
      ReceivedElapsedMs = [Math]::Round($receivedMs, 3)
      ReceiveGapMs = [Math]::Round($receiveGap, 3)
      ProducerGapMs = [Math]::Round($producerGap, 3)
      TransportAfterCaptureMs = [Math]::Round(([DateTimeOffset]::Now.ToUnixTimeMilliseconds() - $pendingMeta.CaptureDoneAt), 3)
      CaptureMs = $pendingMeta.CaptureMs
      Bytes = $pendingMeta.Bytes
      IdGap = $idGap
    })
    $previousId = $pendingMeta.FrameId
    $previousReceiveMs = $receivedMs
    $previousCaptureDoneAt = $pendingMeta.CaptureDoneAt
    $pendingMeta = $null
  }
}
finally {
  $watch.Stop()
  try { $socket.Abort() } catch {}
  $socket.Dispose()
  $cancel.Dispose()
}

$records | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$usableGaps = @($records | Select-Object -Skip 1)
$slidingFps = [Collections.Generic.List[double]]::new()
for ($at = 2000; $at -le ($watch.Elapsed.TotalMilliseconds - 250); $at += 250) {
  $count = @($records | Where-Object { $_.ReceivedElapsedMs -gt ($at - 1000) -and $_.ReceivedElapsedMs -le $at }).Count
  $slidingFps.Add($count)
}
$slowEvents = @($usableGaps | Where-Object { $_.ReceiveGapMs -ge 33 -or $_.ProducerGapMs -ge 33 -or $_.IdGap -gt 0 } |
  Sort-Object ReceiveGapMs -Descending | Select-Object -First 20)
$summary = [ordered]@{
  label = $Label
  durationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3)
  frames = $records.Count
  firstFrameId = if ($records.Count) { $records[0].FrameId } else { 0 }
  lastFrameId = if ($records.Count) { $records[-1].FrameId } else { 0 }
  idGaps = [long](($records | Measure-Object IdGap -Sum).Sum)
  receiveGapP50Ms = [Math]::Round((Get-Percentile @($usableGaps.ReceiveGapMs) 0.50), 3)
  receiveGapP95Ms = [Math]::Round((Get-Percentile @($usableGaps.ReceiveGapMs) 0.95), 3)
  receiveGapMaxMs = [Math]::Round((Get-Percentile @($usableGaps.ReceiveGapMs) 1.00), 3)
  producerGapP95Ms = [Math]::Round((Get-Percentile @($usableGaps.ProducerGapMs) 0.95), 3)
  producerGapMaxMs = [Math]::Round((Get-Percentile @($usableGaps.ProducerGapMs) 1.00), 3)
  transportP95Ms = [Math]::Round((Get-Percentile @($records.TransportAfterCaptureMs) 0.95), 3)
  slidingFpsMin = [Math]::Round((Get-Percentile @($slidingFps) 0.00), 1)
  slidingFpsP05 = [Math]::Round((Get-Percentile @($slidingFps) 0.05), 1)
  slidingFpsMedian = [Math]::Round((Get-Percentile @($slidingFps) 0.50), 1)
  slowEvents = $slowEvents
  csvPath = $csvPath
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 5
