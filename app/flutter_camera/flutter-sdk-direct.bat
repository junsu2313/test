@echo off
setlocal
set "FLUTTER_ROOT=%~dp0.."
set "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
set "TOOL=%FLUTTER_ROOT%\packages\flutter_tools\bin\flutter_tools.dart"
"%DART%" --disable-dart-dev "%TOOL%" %*
exit /B %ERRORLEVEL%
