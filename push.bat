@echo off
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

for /f %%a in ('echo prompt $E^| cmd') do set "CLR=%%a"

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mPulling Remote Changes...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

git pull

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mAdding Files...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

:: Check if there are any changes to commit (either staged or unstaged)
set CHANGES_FOUND=false
for /f "delims=" %%a in ('git status --porcelain') do set "CHANGES_FOUND=true"

:: Only proceed with commit if changes were found
if "%CHANGES_FOUND%" == "true" (
  call :do_commit
  goto :done_checking
)

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mNothing to commit, skipping commit step...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

:: Even if there's nothing to commit, we might still need to push if we have commits that haven't been pushed
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mChecking for commits to push...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

:done_checking

:: Check if there are any commits to push
set COMMITS_TO_PUSH=0
for /f %%a in ('git rev-list --count @{u}..HEAD 2^>nul') do set "COMMITS_TO_PUSH=%%a"

:: Only proceed with push if there are commits to push
if "%COMMITS_TO_PUSH%"=="0" (
    echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
    echo %CLR%[38;2;0;255;255mNo commits to push, skipping push step...%CLR%[0m
    echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
    goto :eof
)

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mPushing...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

git push
set PUSH_RESULT=%ERRORLEVEL%
if not "%PUSH_RESULT%"=="0" (
    echo.
    echo %CLR%[91mGit push failed with error %PUSH_RESULT%%CLR%[0m
    echo.
    exit /b %PUSH_RESULT%
)

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mDONE!%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

goto :eof

:do_commit
git add . 2>nul
git status 2>nul

echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mMaking Commit Message...%CLR%[0m
echo %CLR%[38;2;0;255;255m----------------------------------------%CLR%[0m

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
powershell -NoProfile -Command "Get-Content '%PROMPT_FILE%' | agent \"Make git commit message. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). Return only the commit message, nothing else.\" | Out-File -FilePath '%MSG_FILE%' -Encoding UTF8"

del "%PROMPT_FILE%"

:: use PowerShell to read the commit message and strip BOM
powershell -NoProfile -Command "$content = Get-Content -Raw -Path '%MSG_FILE%' -Encoding UTF8; if ($content.StartsWith((0xEF,0xBB,0xBF) -join '')) { $content = $content.Substring(3) }; $content.Trim() | Out-File -FilePath '%MSG_FILE%' -Encoding ASCII"

:: read the cleaned commit message
set /p COMMIT_MSG=<"%MSG_FILE%"

:: delete the temp file
if exist "%MSG_FILE%" del "%MSG_FILE%"

:: Check if we got a commit message, if not abort everything
if defined COMMIT_MSG (
    echo %CLR%[93m%COMMIT_MSG%%CLR%[0m
    git commit -m "%COMMIT_MSG%"
) else (
    echo.
    echo %CLR%[91mAI failed to generate commit message. Aborting...%CLR%[0m
    echo.
    exit /b 1
)
goto :eof