@echo off
setlocal
set "KEYDIR=%~dp0..\..\artifacts\ssh"
if not exist "%KEYDIR%" mkdir "%KEYDIR%"
if not exist "%KEYDIR%\opal-tailscale_ed25519" ssh-keygen.exe -q -t ed25519 -f "%KEYDIR%\opal-tailscale_ed25519" -N "" -C "opal-tailscale-backup"
if not exist "%KEYDIR%\opal-ssid_ed25519" ssh-keygen.exe -q -t ed25519 -f "%KEYDIR%\opal-ssid_ed25519" -N "" -C "opal-ssid-fallback"
endlocal
