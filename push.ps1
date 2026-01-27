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
    Write-Host " $Message " -ForegroundColor White -BackgroundColor Green
    Write-Host
}

function Write-Error {
    param([string]$Message)
    Write-Host
    Write-Host " $Message " -ForegroundColor White -BackgroundColor Red
    Write-Host
}

function Write-Warning {
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

# Show current branch and status
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch: $currentBranch" -ForegroundColor Green

# Show ahead/behind summary
git status -sb

# Pulling remote changes
Write-Section "Pulling Remote Changes..."
git pull
if ($LASTEXITCODE -ne 0) {
    Write-Error "Git pull failed with error $LASTEXITCODE. Exiting..."
    exit $LASTEXITCODE
}

# Adding files
Write-Section "Adding Files..."
git add . 2>$null | Out-Null
git status 2>$null | Out-Null

# Check if there are any staged changes
$stagedFiles = git diff --cached --name-only
if ($stagedFiles) {
    # Make commit
    Write-Section "Making Commit..."

    # Build prompt from git diff --cached (actual 50KB byte-based truncation)
    $msgFile = Join-Path $env:TEMP "commit_msg.txt"
    $agentScriptFile = Join-Path $env:TEMP "agent_call.ps1"

    # Get stats
    $stats = git diff --cached --stat | Out-String

    # Get diff and truncate to exactly 50KB using bytes
    $diffFile = Join-Path $env:TEMP "diff_full.txt"
    $diffTruncFile = Join-Path $env:TEMP "diff_trunc.txt"
    git diff --cached | Out-File -FilePath $diffFile -Encoding UTF8
    $bytes = [System.IO.File]::ReadAllBytes($diffFile)
    $len = [Math]::Min(50000, $bytes.Length)
    [System.IO.File]::WriteAllBytes($diffTruncFile, $bytes[0..($len-1)])
    $diffContent = [System.IO.File]::ReadAllText($diffTruncFile, [System.Text.Encoding]::UTF8)

    # Create a script that calls agent with diff embedded
    $scriptContent = @"
`$diff = @'
$diffContent
'@

try {
    `$result = agent "Write ONE conventional commit message. Files changed: $stats Use feat, fix, docs, chore, refactor, test, perf, ci, build, style, or revert. Single line, max 100 chars. RETURN ONLY THE COMMIT MESSAGE." 2>&1 | Select-Object -First 1
    `$result = `$result.Trim()
    Write-Output `$result
} catch {
    Write-Error "Agent call failed: `$_. Using fallback."
    Write-Output "chore: update"
    exit 1
}
"@
    $scriptContent | Out-File -FilePath $agentScriptFile -Encoding UTF8

    # Execute script with error handling
    try {
        $result = & $agentScriptFile 2>&1 | Select-Object -First 1
        $result = $result.Trim()

        # Validate result (basic check)
        if ($result -match "^[a-z]+(\([a-z]+\))?:.+" -and $result.Length -le 100 -and $result.Length -gt 0) {
            $commitMsg = $result
        } else {
            Write-Warning "Invalid commit format from agent. Using fallback."
            $commitMsg = "chore: update"
        }

        $commitMsg | Out-File -FilePath $msgFile -Encoding ASCII -NoNewline
    } catch {
        Write-Error "Agent execution failed. Using fallback: $_"
        "chore: update" | Out-File -FilePath $msgFile -Encoding ASCII -NoNewline
        $commitMsg = "chore: update"
    } finally {
        Remove-Item $diffFile, $diffTruncFile, $agentScriptFile -ErrorAction SilentlyContinue
    }

    # Read commit message
    if (Test-Path $msgFile) {
        $commitMsg = Get-Content -Path $msgFile -Raw -Encoding ASCII
        Remove-Item $msgFile -ErrorAction SilentlyContinue
    }

    Write-Success $commitMsg
    git commit -m $commitMsg
}

# Check for commits to push
Write-Section "Checking for commits to push..."

# Check if upstream exists
git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "No upstream configured. Setting up upstream..."
    $hasUpstream = $false
} else {
    $hasUpstream = $true
}

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

# Pushing
Write-Section "Pushing..."

if (-not $hasUpstream) {
    git push -u origin $currentBranch
} else {
    # Show remote being pushed to
    $remoteUrl = git remote get-url origin 2>$null
    if ($remoteUrl) {
        Write-Host "Pushing to: $remoteUrl" -ForegroundColor Green
    }
    git push
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Git push failed with error $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Success "DONE!"
