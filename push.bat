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

:: Check if there are any changes to commit (either staged or unstaged)
set CHANGES_FOUND=false
for /f "delims=" %%a in ('git status --porcelain') do set "CHANGES_FOUND=true"

:: Only proceed with commit if changes were found
if "%CHANGES_FOUND%" == "true" (
  call :do_commit
  goto :done_checking
)

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mNothing to commit, skipping commit step...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

:: Even if there's nothing to commit, we might still need to push if we have commits that haven't been pushed
echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mChecking for commits to push...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

:done_checking

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mPushing...%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

git status

:: show last commit message (from git history) in yellow before pushing
:: get the last commit message subject directly without using temp file
for /f "delims=" %%M in ('git log -1 --pretty^=format^:^"%s"') do set "LAST_COMMIT=%%M"
echo %ESC%[93mLast commit by AI:%ESC%[0m
echo %ESC%[93m%LAST_COMMIT%%ESC%[0m

git push
set PUSH_RESULT=%ERRORLEVEL%
if %PUSH_RESULT% neq 0 (
    echo.
    echo Git push failed with error %PUSH_RESULT%
    echo.
    exit /b %PUSH_RESULT%
)

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mDONE!%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m

goto :eof

:do_commit
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

:: create a temporary file to store the commit message
set "MSG_FILE=%TEMP%\commit_msg.txt"

:: use PowerShell to pipe the prompt file to agent and capture output
powershell -Command "Get-Content '%PROMPT_FILE%' | agent \"Make git commit message. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). Return only the commit message, nothing else.\" | Out-File -FilePath '%MSG_FILE%' -Encoding UTF8"

del "%PROMPT_FILE%"

:: read the commit message from the temp file
set /p COMMIT_MSG=<"%MSG_FILE%"

:: delete the temp file
if exist "%MSG_FILE%" del "%MSG_FILE%"

:: Check if we got a commit message, if not abort everything
if defined COMMIT_MSG (
    echo Commit message generated: %COMMIT_MSG%
    git commit -m "%COMMIT_MSG%"
) else (
    echo.
    echo AI failed to generate commit message. Aborting...
    echo.
    exit /b 1
)
goto :eof