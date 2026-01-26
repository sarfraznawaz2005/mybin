@echo off
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

for /f %%a in ('echo prompt $E^| cmd') do set "CYAN=%%a"

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mPulling Remote Changes...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

git pull

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mAdd Files...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

git status
git add .

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mMaking Commit Message...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

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

:: pipe prompt into agent to get the commit message
for /f "usebackq delims=" %%M in (`type "%PROMPT_FILE%" ^| agent "Make git commit message. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). Return only the commit message, nothing else."`) do set "COMMIT_MSG=%%M"

del "%PROMPT_FILE%"

:: Check if we got a commit message, if not abort everything
if defined COMMIT_MSG (
    git commit -m "%COMMIT_MSG%"
) else (
    echo.
    echo AI failed to generate commit message. Aborting...
    echo.
    exit /b 1
)

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mPushing...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

git status

:: show last commit message (from git history) in yellow before pushing
:: get the last commit message subject into a temp file to avoid percent-expansion issues
set "LAST_FILE=%TEMP%\last_commit.txt"
git log -1 --pretty=format:%s > "%LAST_FILE%"
for /f "usebackq delims=" %%M in ("%LAST_FILE%") do set "LAST_COMMIT=%%M"
echo %ESC%[93mLast commit by AI:%ESC%[0m
echo %ESC%[93m%LAST_COMMIT%%ESC%[0m
if exist "%LAST_FILE%" del "%LAST_FILE%"

git push

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mDONE!%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m