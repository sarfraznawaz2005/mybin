@echo off
setlocal
set "PS1=%~dp0GeminiPS.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal
