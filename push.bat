@echo off
setlocal enabledelayedexpansion
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

for /f %%a in ('echo prompt $E^| cmd') do set "CLR=%%a"

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mChecking Repository State...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

:: Check if we're in a git repository
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo %CLR%[91mNot in a git repository. Exiting...%CLR%[0m
    exit /b 1
)

:: Check for merge conflicts
for /f "delims=" %%a in ('git status --porcelain ^| findstr "^UU"') do (
    echo %CLR%[91mMerge conflict in progress. Please resolve conflicts first. Exiting...%CLR%[0m
    exit /b 1
)

:: Show current branch and status
for /f %%a in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%a"
echo Current branch: %CLR%[93m%CURRENT_BRANCH%%CLR%[0m

:: Show ahead/behind summary
git status -sb

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mPulling Remote Changes...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

git pull
set PULL_RESULT=%ERRORLEVEL%
if not "%PULL_RESULT%"=="0" (
    echo.
    echo %CLR%[91mGit pull failed with error %PULL_RESULT%. Exiting...%CLR%[0m
    echo.
    exit /b %PULL_RESULT%
)

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mAdding Files...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

git add . 2>nul
git status 2>nul

:: Check if there are any staged changes
set STAGED_FOUND=false
for /f "delims=" %%a in ('git diff --cached --name-only') do set "STAGED_FOUND=true"

:: Only proceed with commit if staged changes were found
if "%STAGED_FOUND%" == "true" (
    call :do_commit
    goto :done_checking
)

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mNo staged changes, skipping AI commit message...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

:: Even if there's nothing to commit, we might still need to push if we have commits that haven't been pushed
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mChecking for commits to push...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

:done_checking

:: Check if upstream exists
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1
if errorlevel 1 (
    echo %CLR%[93mNo upstream configured. Setting up upstream...%CLR%[0m
    set HAS_UPSTREAM=false
) else (
    set HAS_UPSTREAM=true
)

:: Check if there are any commits to push
set COMMITS_TO_PUSH=0
if "%HAS_UPSTREAM%"=="true" (
    for /f %%a in ('git rev-list --count @{u}..HEAD 2^>nul') do set "COMMITS_TO_PUSH=%%a"
) else (
    :: If no upstream, check if there are any commits at all
    for /f %%a in ('git rev-list --count HEAD 2^>nul') do set "COMMITS_TO_PUSH=%%a"
)

:: Only proceed with push if there are commits to push
if "%COMMITS_TO_PUSH%"=="0" (
    echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
    echo %CLR%[38;2;0;255;255mNo commits to push, skipping push step...%CLR%[0m
    echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

    echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
    echo %CLR%[38;2;0;255;255mDONE!%CLR%[0m
    echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
    goto :eof
)

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mPushing...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

if "%HAS_UPSTREAM%"=="false" (
    echo %CLR%[93mSetting upstream to origin/%CURRENT_BRANCH%...%CLR%[0m
    git push -u origin %CURRENT_BRANCH%
) else (
    :: Show remote being pushed to
    for /f "delims=" %%a in ('git remote get-url origin') do set "REMOTE_URL=%%a"
    if defined REMOTE_URL (
        echo Pushing to: %CLR%[93m%REMOTE_URL%%CLR%[0m
    )
    git push
)
set PUSH_RESULT=%ERRORLEVEL%
if not "%PUSH_RESULT%"=="0" (
    echo.
    echo %CLR%[91mGit push failed with error %PUSH_RESULT%%CLR%[0m
    echo.
    exit /b %PUSH_RESULT%
)

echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mDONE!%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

goto :eof

:do_commit
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m
echo %CLR%[38;2;0;255;255mMaking Commit Message...%CLR%[0m
echo %CLR%[38;2;0;255;255m--------------------------------------------------%CLR%[0m

:: build prompt file and capture git diff --cached truncated to 50000 bytes
set "FULL=%TEMP%\git_diff_full.txt"
set "TRUNC=%TEMP%\git_diff_trunc.txt"
set "PROMPT_FILE=%TEMP%\git_diff_prompt.txt"
(echo ^(=== Summary ===^) ) > "%PROMPT_FILE%"
git diff --cached --stat >> "%PROMPT_FILE%"
echo. >> "%PROMPT_FILE%"
(echo ^(=== Diff ^(truncated if large^) ===^) ) >> "%PROMPT_FILE%"
:: use PowerShell to write full diff to file, then write first 50000 bytes (50kb) to trunc and append to prompt file
powershell -NoProfile -Command "git diff --cached | Out-File -FilePath '%FULL%' -Encoding UTF8; $b=[System.IO.File]::ReadAllBytes('%FULL%'); $len=[System.Math]::Min(50000,$b.Length); [System.IO.File]::WriteAllBytes('%TRUNC%',$b[0..($len-1)]); Get-Content -Encoding UTF8 -Path '%TRUNC%' | Out-File -FilePath '%PROMPT_FILE%' -Encoding UTF8 -Append; Remove-Item '%FULL%','%TRUNC%'"

:: create a temporary file to store the commit message
set "MSG_FILE=%TEMP%\commit_msg.txt"

:: use PowerShell to pipe the prompt file to agent and capture output
powershell -NoProfile -Command "Get-Content '%PROMPT_FILE%' | agent 'Make git commit message. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, refactor, test, perf, ci, build, style, revert). You may include a scope in parentheses like feat(scope):. Use ! for breaking changes. Return only the commit message, nothing else.' | Out-File -FilePath '%MSG_FILE%' -Encoding UTF8"

del "%PROMPT_FILE%"

:: use PowerShell to read the commit message and strip BOM
powershell -NoProfile -Command "$content = Get-Content -Raw -Path '%MSG_FILE%' -Encoding UTF8; if ($content.StartsWith((0xEF,0xBB,0xBF) -join '')) { $content = $content.Substring(3) }; $content.Trim() | Out-File -FilePath '%MSG_FILE%' -Encoding ASCII"

:: read the cleaned commit message
set /p COMMIT_MSG=<"%MSG_FILE%"

:: delete the temp file
if exist "%MSG_FILE%" del "%MSG_FILE%"

:: Validate commit message
set "VALID_MSG=false"
if defined COMMIT_MSG (
    :: Check if it's a single line (no newlines)
    echo !COMMIT_MSG! | findstr /r /c:"[\r\n]" >nul
    if errorlevel 1 (
        :: Check length (max 100 chars)
        set /p "LEN=.<nul" | powershell -NoProfile -Command "'!COMMIT_MSG!'.Length" >nul
        for /f %%a in ('powershell -NoProfile -Command "'!COMMIT_MSG!'.Length"') do set "MSG_LEN=%%a"
        if !MSG_LEN! LEQ 100 (
            :: Check for valid prefix
            echo !COMMIT_MSG! | findstr /r /c:"^feat[(:]" /c:"^fix[(:]" /c:"^docs[(:]" /c:"^chore[(:]" /c:"^refactor[(:]" /c:"^test[(:]" /c:"^perf[(:]" /c:"^ci[(:]" /c:"^build[(:]" /c:"^style[(:]" /c:"^revert[(:]" >nul
            if not errorlevel 1 (
                :: Check for invalid characters (quotes, markdown, html)
                echo !COMMIT_MSG! | findstr /r /c:"[""']" /c:"\*\*" /c:"__" /c:"<[^>]*>" >nul
                if errorlevel 1 (
                    set "VALID_MSG=true"
                )
            )
        )
    )
)

:: If invalid, fall back to generic message
if "!VALID_MSG!"=="false" (
    echo %CLR%[93mInvalid commit message format. Falling back to generic message...%CLR%[0m
    set "COMMIT_MSG=chore: update"
    echo %CLR%[93m%COMMIT_MSG%%CLR%[0m
) else (
    echo %CLR%[93m%COMMIT_MSG%%CLR%[0m
)

git commit -m "%COMMIT_MSG%"
goto :eof
