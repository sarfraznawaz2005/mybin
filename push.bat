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
echo %CLR%[38;2;0;255;255mMaking Commit...%CLR%[0m
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

:: Store current HEAD to verify commit later
for /f %%a in ('git rev-parse HEAD') do set "BEFORE_COMMIT=%%a"

:: Let agent create the commit directly
powershell -NoProfile -Command "Get-Content '%PROMPT_FILE%' -Raw | agent 'Review the staged changes and create a git commit. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, refactor, test, perf, ci, build, style, revert). You may include a scope in parentheses like feat(scope):. Use ! for breaking changes. Use \"git commit -m message\" to create the commit with the appropriate message. Return only the commit message you used, nothing else.'"

del "%PROMPT_FILE%"

:: Verify if commit was made by checking if HEAD changed
for /f %%a in ('git rev-parse HEAD') do set "AFTER_COMMIT=%%a"
if "!BEFORE_COMMIT!"=="!AFTER_COMMIT!" (
    echo.
    echo %CLR%[91mNo commit was created. Falling back to generic commit...%CLR%[0m
    git commit -m "chore: update"
) else (
    echo %CLR%[93mCommit created successfully%CLR%[0m
)

goto :eof
