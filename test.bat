@echo off
:: test.bat - print `git diff HEAD` truncated to 50000 bytes (works in cmd.exe)
set "FULL=%TEMP%\git_diff_full.txt"
set "TRUNC=%TEMP%\git_diff_trunc.txt"

:: Use PowerShell to capture full diff to a file and then write first 50000 bytes to trunc file
powershell -NoProfile -Command "git diff HEAD | Out-File -FilePath '%FULL%' -Encoding UTF8; $b = [System.IO.File]::ReadAllBytes('%FULL%'); $len = [System.Math]::Min(50000, $b.Length); [System.IO.File]::WriteAllBytes('%TRUNC%', $b[0..($len-1)]); Get-Content -Encoding UTF8 -Path '%TRUNC%'; Remove-Item '%FULL%','%TRUNC%'"

pause
