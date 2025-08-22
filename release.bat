:: usage
:: release 1.0.18 main

@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Prefer pwsh if installed
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (set "_PS=pwsh.exe") else (set "_PS=powershell.exe")

where git.exe >nul 2>&1 || (echo [ERROR] Git not found & exit /b 1)
where gh.exe  >nul 2>&1 || (echo [ERROR] GitHub CLI not found & exit /b 1)

set "_HERE=%~dp0"
set "_SCRIPT=%_HERE%make-release.ps1"

if not exist "%_SCRIPT%" (
  echo [ERROR] Can't find "%_SCRIPT%".
  exit /b 1
)

if "%~1"=="" (
  echo Usage: %~nx0 ^<Tag^> [TargetBranch]
  echo Example: %~nx0 v1.0.18 main
  exit /b 2
)

"%_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%_SCRIPT%" -Tag "%~1" -Target "%~2"

set "RC=%ERRORLEVEL%"
if %RC% NEQ 0 (
  echo [ERROR] Release script failed with code %RC%.
  exit /b %RC%
)

echo [OK] Release created successfully.
exit /b 0
