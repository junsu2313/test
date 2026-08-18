param(
  [Parameter(Mandatory = $true)]
  [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'

$deployRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $deployRoot
$packageSrc = Join-Path $deployRoot 'openwrt\ddserver'
$cmakeSrc = Join-Path $repoRoot '_tmp_ddserver\CMakeLists.txt'
$sourceSrc = Join-Path $repoRoot '_tmp_ddserver\src'
$targetPkg = Join-Path $SdkRoot 'package\ddserver'
$targetSrc = Join-Path $targetPkg 'src'

if (-not (Test-Path $packageSrc)) {
  throw "Missing package source: $packageSrc"
}

if (-not (Test-Path $sourceSrc)) {
  throw "Missing ddserver source: $sourceSrc"
}

if (-not (Test-Path $SdkRoot)) {
  throw "SDK root does not exist: $SdkRoot"
}

New-Item -ItemType Directory -Force -Path $targetPkg | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $targetPkg 'files') | Out-Null
Copy-Item -Path (Join-Path $packageSrc '*') -Destination $targetPkg -Recurse -Force
Copy-Item -Path $cmakeSrc -Destination $targetPkg -Force
# deploy/openwrt/ddserver/files is authoritative.  _tmp_ddserver/files still
# contains the upstream non-procd init script and must not overwrite it.
New-Item -ItemType Directory -Force -Path $targetSrc | Out-Null
Copy-Item -Path (Join-Path $sourceSrc '*') -Destination $targetSrc -Recurse -Force

Write-Host "Staged ddserver package into $targetPkg"
Write-Host "Next step: run `make package/ddserver/compile V=s` from the OpenWrt SDK root."
