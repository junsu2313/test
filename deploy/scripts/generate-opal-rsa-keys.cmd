@echo off
setlocal
set "KEYDIR=%~dp0..\..\artifacts\ssh"
if not exist "%KEYDIR%" mkdir "%KEYDIR%"
if not exist "%KEYDIR%\opal-tailscale_rsa" ssh-keygen.exe -q -t rsa -b 3072 -f "%KEYDIR%\opal-tailscale_rsa" -N "" -C "opal-tailscale-backup"
if not exist "%KEYDIR%\opal-ssid_rsa" ssh-keygen.exe -q -t rsa -b 3072 -f "%KEYDIR%\opal-ssid_rsa" -N "" -C "opal-ssid-fallback"
endlocal
