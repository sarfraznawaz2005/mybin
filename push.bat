@echo off
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

git pull
git status
git add .

:: build prompt file and capture git diff HEAD truncated to 50000 bytes so we don't bombard AI with lot of context consuming our tokens!
set "FULL=%TEMP%\git_diff_full.txt"
set "TRUNC=%TEMP%\git_diff_trunc.txt"
set "PROMPT_FILE=%TEMP%\git_diff_prompt.txt"
(echo ^(=== Summary ===^) ) > "%PROMPT_FILE%"
git diff HEAD --stat >> "%PROMPT_FILE%"
echo. >> "%PROMPT_FILE%"
(echo ^(=== Diff ^(truncated if large^) ===^) ) >> "%PROMPT_FILE%"
:: use PowerShell to write full diff to file, then write first 50000 bytes to trunc and append to prompt file
powershell -NoProfile -Command "git diff HEAD | Out-File -FilePath '%FULL%' -Encoding UTF8; $b=[System.IO.File]::ReadAllBytes('%FULL%'); $len=[System.Math]::Min(50000,$b.Length); [System.IO.File]::WriteAllBytes('%TRUNC%',$b[0..($len-1)]); Get-Content -Encoding UTF8 -Path '%TRUNC%' | Out-File -FilePath '%PROMPT_FILE%' -Encoding UTF8 -Append; Remove-Item '%FULL%','%TRUNC%'"

:: pipe prompt into agent
:: pipe prompt into agent, capture its stdout (the commit message) into a file
set "COMMIT_OUT=%TEMP%\ai_commit_msg.txt"
type "%PROMPT_FILE%" | agent "Make git commit message. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). Output ONLY the single-line commit message and then exit." > "%COMMIT_OUT%"

:: perform git commit using AI output file as fallback; prefer to let agent write commit via git if it already did
:: Try to read AI's provided message; if present use it, otherwise proceed to check latest git commit
setlocal enabledelayedexpansion
set "AI_MSG="
for /f "usebackq delims=" %%M in ("%COMMIT_OUT%") do set "AI_MSG=%%M"
endlocal & set "AI_MSG=%AI_MSG%"

if not "%AI_MSG%"=="" (
  git commit -m "%AI_MSG%"
  set "COMMITTED_MSG=%AI_MSG%"
) else (
  :: AI didn't output directly; assume agent may have committed itself — read the most recent commit message
  for /f "usebackq delims=" %%C in ('git log -1 --pretty=%%s') do set "COMMITTED_MSG=%%C"
)

:: show the last committed message in yellow
echo %ESC%[93mLast committed message:%ESC%[0m
echo %ESC%[93m%COMMITTED_MSG%%ESC%[0m

del "%COMMIT_OUT%"

del "%PROMPT_FILE%"

del "%COMMIT_OUT%"

del "%PROMPT_FILE%"

pause

git status
git push 

:: using these manual commands to verify AI actually did push
echo %ESC%[92m-- AI Operation Verification --%ESC%[0m

git status
git push
