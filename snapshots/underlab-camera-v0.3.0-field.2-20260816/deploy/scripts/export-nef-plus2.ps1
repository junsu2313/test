param(
  [Parameter(Mandatory = $true)][string]$InputNef,
  [string]$TemplateXmp = '',
  [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $TemplateXmp) { $TemplateXmp = Join-Path $scriptRoot '..\..\CAMERA\d810\NEF\2026_06_17\DSC_7467.NEF.xmp' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $scriptRoot '..\..\CAMERA\d810\processed' }
$inputPath = [System.IO.Path]::GetFullPath($InputNef)
$templatePath = [System.IO.Path]::GetFullPath($TemplateXmp)
$outputDir = [System.IO.Path]::GetFullPath($OutputDirectory)
$darktableCandidates = @(
  'C:\darktable\bin\darktable-cli.exe',
  'C:\Program Files\darktable\bin\darktable-cli.exe'
)
$darktable = $darktableCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not (Test-Path -LiteralPath $inputPath)) { throw "NEF not found: $inputPath" }
if (-not (Test-Path -LiteralPath $templatePath)) { throw "XMP template not found: $templatePath" }
if (-not $darktable) {
  throw "darktable-cli not found. Checked: $($darktableCandidates -join ', ')"
}

[System.IO.Directory]::CreateDirectory($outputDir) | Out-Null
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
$xmpPath = Join-Path $outputDir "$baseName-plus2.xmp"
$outputPath = Join-Path $outputDir "$baseName-plus2.jpg"

$xmp = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8
$xmp = [regex]::Replace($xmp, 'xmpMM:DerivedFrom="[^"]*"', "xmpMM:DerivedFrom=`"$([System.IO.Path]::GetFileName($inputPath))`"", 1)
$exposurePattern = '(?s)(darktable:operation="exposure".*?darktable:params=")[^"]+(")'
$plusTwoParams = '00000000000000000000004000004842000080c00000000000000000'
$updated = [regex]::Replace($xmp, $exposurePattern, "`${1}$plusTwoParams`${2}", 1)
if ($updated -eq $xmp) { throw 'Exposure module parameters were not found in the XMP template' }
[System.IO.File]::WriteAllText($xmpPath, $updated, [System.Text.UTF8Encoding]::new($false))

$runtimeRoot = 'C:\darktable'
$configDir = Join-Path $runtimeRoot 'config'
$cacheDir = Join-Path $runtimeRoot 'cache'
$tempDir = Join-Path $runtimeRoot 'tmp'
foreach ($directory in @($runtimeRoot, $configDir, $cacheDir, $tempDir)) {
  [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}
$library = Join-Path $runtimeRoot 'library.db'

$cliInput = $inputPath.Replace('\', '/')
$cliXmp = $xmpPath.Replace('\', '/')
$cliOutput = $outputPath.Replace('\', '/')
$cliConfig = $configDir.Replace('\', '/')
$cliCache = $cacheDir.Replace('\', '/')
$cliTemp = $tempDir.Replace('\', '/')
$cliLibrary = $library.Replace('\', '/')

& $darktable $cliInput $cliXmp $cliOutput '--width' '0' '--height' '0' '--hq' 'true' '--apply-custom-presets' 'false' '--core' '--configdir' $cliConfig '--cachedir' $cliCache '--tmpdir' $cliTemp '--library' $cliLibrary
if ($LASTEXITCODE -ne 0) { throw "darktable-cli failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $outputPath)) { throw "darktable did not create output: $outputPath" }

Get-Item -LiteralPath $outputPath | Select-Object FullName, Length, LastWriteTime
