# ANSI colors
$ESC = [char]27
$CLR = $ESC

Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mChecking Repository State...$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

# Check if we're in a git repository
$null = git rev-parse --git-dir 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "$CLR[91mNot in a git repository. Exiting...$CLR[0m"
    exit 1
}

# Check for merge conflicts
$conflicts = git status --porcelain | Select-String "^UU"
if ($conflicts) {
    Write-Host "$CLR[91mMerge conflict in progress. Please resolve conflicts first. Exiting...$CLR[0m"
    exit 1
}

# Show current branch and status
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch: $CLR[93m$currentBranch$CLR[0m"

# Show ahead/behind summary
git status -sb

Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mPulling Remote Changes...$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "$CLR[91mGit pull failed with error $LASTEXITCODE. Exiting...$CLR[0m"
    Write-Host ""
    exit $LASTEXITCODE
}

Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mAdding Files...$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

git add . 2>$null
git status 2>$null | Out-Null

# Check if there are any staged changes
$stagedFiles = git diff --cached --name-only
if ($stagedFiles) {
    # Make commit
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255mMaking Commit...$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

    # Build prompt from git diff --cached with smart filtering
    $msgFile = Join-Path $env:TEMP "commit_msg.txt"

    # Get raw diff and filter for meaningful content
    $diffLines = git diff --cached | Out-String -Stream
    $filteredDiff = $diffLines | Where-Object { $_.StartsWith('+') -or $_.StartsWith('-') -or $_ -match '^diff --git' -or $_ -match '^@@' } | Select-Object -First 100 | Out-String

    # Create prompt with stats and filtered diff
    $stats = git diff --cached --stat | Out-String
    $prompt = "Write ONE conventional commit message. Files changed:
$stats
Filtered diff:
$filteredDiff

Use feat, fix, docs, chore, refactor, test, perf, ci, build, style, or revert. Single line, max 100 chars. RETURN ONLY THE COMMIT MESSAGE."

    # Call agent with filtered content
    $result = agent $prompt 2>&1 | Select-Object -First 1
    $result = $result.Trim()
    
    $result | Out-File -FilePath $msgFile -Encoding ASCII -NoNewline
    
    Remove-Item $promptFile -ErrorAction SilentlyContinue

    # Read commit message
    $commitMsg = ""
    if (Test-Path $msgFile) {
        $commitMsg = Get-Content -Path $msgFile -Raw -Encoding ASCII
        Remove-Item $msgFile -ErrorAction SilentlyContinue
    }
    
    Write-Host "$CLR[93m$commitMsg$CLR[0m"

    git commit -m $commitMsg
}

# Check for commits to push
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mChecking for commits to push...$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

# Check if upstream exists
$upstreamBranch = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1
$hasUpstream = $LASTEXITCODE -eq 0

$commitsToPush = 0
if ($hasUpstream) {
    $commitsToPush = git rev-list --count "@{u}..HEAD" 2>$null
    if ([string]::IsNullOrWhiteSpace($commitsToPush)) { $commitsToPush = 0 }
} else {
    Write-Host "$CLR[93mNo upstream configured. Setting up upstream...$CLR[0m"
    $commitsToPush = git rev-list --count HEAD 2>$null
    if ([string]::IsNullOrWhiteSpace($commitsToPush)) { $commitsToPush = 0 }
}

# Only proceed with push if there are commits to push
if ($commitsToPush -eq 0) {
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255mNo commits to push, skipping push step...$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255mDONE!$CLR[0m"
    Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
    exit 0
}

Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mPushing...$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"

if (-not $hasUpstream) {
    git push -u origin $currentBranch
} else {
    # Show remote being pushed to
    $remoteUrl = git remote get-url origin 2>$null
    if ($remoteUrl) {
        Write-Host "Pushing to: $CLR[93m$remoteUrl$CLR[0m"
    }
    git push
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "$CLR[91mGit push failed with error $LASTEXITCODE$CLR[0m"
    Write-Host ""
    exit $LASTEXITCODE
}

Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
Write-Host "$CLR[38;2;0;255;255mDONE!$CLR[0m"
Write-Host "$CLR[38;2;0;255;255m--------------------------------------------------$CLR[0m"
