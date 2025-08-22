@echo off
setlocal
set "PS1=%~dp0Gemini.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal
