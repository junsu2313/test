@echo off
setlocal
set "KEYDIR=%~dp0..\..\artifacts\ssh"
ssh-keygen.exe -p -m PEM -P "" -N "" -f "%KEYDIR%\opal-tailscale_rsa"
ssh-keygen.exe -p -m PEM -P "" -N "" -f "%KEYDIR%\opal-ssid_rsa"
endlocal
