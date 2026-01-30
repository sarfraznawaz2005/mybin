# Helper functions for colored output
function Write-Header {
    param([string]$Message)
    Write-Host
    Write-Host " $Message " -ForegroundColor Black -BackgroundColor Cyan
    Write-Host
}

function Write-Section {
    param([string]$Message)
    Write-Host
    Write-Host " $Message " -ForegroundColor Black -BackgroundColor Green
    Write-Host
}

function Write-Error {
    param([string]$Message)
    Write-Host
    Write-Host " $Message " -ForegroundColor White -BackgroundColor Red
    Write-Host
}

function Write-Info {
    param([string]$Message)
    Write-Host
    Write-Host " $Message " -ForegroundColor Black -BackgroundColor Yellow
    Write-Host
}

function Write-Success {
    param([string]$Message)
    Write-Section $Message
}

# Check if we're in a git repository
Write-Section "Checking Repository State..."
git rev-parse --git-dir 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not in a git repository. Exiting..."
    exit 1
}

# Check for merge conflicts
$conflicts = git status --porcelain | Select-String "^UU"
if ($conflicts) {
    Write-Error "Merge conflict in progress. Please resolve conflicts first. Exiting..."
    exit 1
}

# Show ahead/behind summary
git status -sb

# Get current branch name
$currentBranch = git rev-parse --abbrev-ref HEAD
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    Write-Error "Could not determine current branch. Exiting..."
    exit 1
}

# Check if upstream exists
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Info "No upstream configured. Skipping pull..."
    $hasUpstream = $false
} else {
    $hasUpstream = $true
    # Pulling remote changes
    Write-Section "Pulling Remote Changes..."
    git pull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git pull failed with error $LASTEXITCODE. Exiting..."
        exit $LASTEXITCODE
    }
}

# add files
git add . 2>$null | Out-Null

# Check if there are any staged changes
$stagedFiles = git diff --cached --name-only
if ($stagedFiles) {
    # Make commit
    Write-Section "Making Commit..."

    # Get stats for context
    $stats = git diff --cached --stat | Out-String

    # Build prompt for agent - let agent handle diff internally
    $prompt = "Carefully analyze the currently staged changes in this git repository and write a correct conventional commit message based on changes/diff.

To see what changed, run: git diff --cached

Stats:
$stats

Format: type: description (single-line, lowercase type, lowercase description, max 100 chars)

Types: feat, fix, docs, chore, refactor, test, perf, ci, build, style, revert

Return ONLY the commit message, nothing else."

    $promptFile = Join-Path $env:TEMP "commit_prompt.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8

    # Execute script with error handling
    try {
        $output = agent -f $promptFile 2>&1
        $result = $output | Select-Object -Skip 1 | Select-Object -First 1
        $result = $result.Trim()
        $commitMsg = $result
    } catch {
        Write-Error "Agent execution failed. Using fallback: $_"
        $commitMsg = "chore: update"
    } finally {
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }

    Write-Info $commitMsg
    git commit -m $commitMsg
}

# Check for commits to push
Write-Section "Checking for commits to push..."

# Check if there are any commits to push
$commitsToPush = 0
if ($hasUpstream) {
    $commitsToPush = git rev-list --count "@{u}..HEAD" 2>$null
    if ([string]::IsNullOrWhiteSpace($commitsToPush)) { $commitsToPush = 0 }
} else {
    # If no upstream, check if there are any commits at all
    $commitsToPush = git rev-list --count HEAD 2>$null
    if ([string]::IsNullOrWhiteSpace($commitsToPush)) { $commitsToPush = 0 }
}

# Only proceed with push if there are commits to push
if ($commitsToPush -eq 0) {
    Write-Section "No commits to push, skipping push step..."
    Write-Success "DONE!"
    exit 0
}

# Check if any remote repository exists
$remotes = git remote 2>$null
if ([string]::IsNullOrWhiteSpace($remotes)) {
    Write-Section "No remote repository configured. Skipping push step..."
    Write-Success "DONE!"
    exit 0
}

# Pushing
Write-Section "Pushing..."

if (-not $hasUpstream) {
    git push -u origin $currentBranch
} else {
    git push
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Git push failed with error $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Success "DONE!"
