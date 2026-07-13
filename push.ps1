# ─── Configuration ─────────────────────────────────────────────────────────────
$MODELS_URL     = "https://models.inference.ai.azure.com/chat/completions"
$AI_MODEL       = "gpt-4o-mini"
$MAX_DIFF_CHARS = 8000
$COMMIT_PATTERN = '^(feat|fix|docs|chore|refactor|test|perf|ci|build|style|revert)(\(.+\))?: .{3,97}$'

# ─── Output helpers (ANSI sequences — avoids full-line background color fill) ──
$ESC = [char]27
function Write-Header  { param([string]$Message); Write-Host; Write-Host "$script:ESC[30;46m $Message $script:ESC[0m"; Write-Host }
function Write-Section { param([string]$Message); Write-Host; Write-Host "$script:ESC[30;42m $Message $script:ESC[0m"; Write-Host }
function Write-Err     { param([string]$Message); Write-Host; Write-Host "$script:ESC[37;41m $Message $script:ESC[0m"; Write-Host }
function Write-Info    { param([string]$Message); Write-Host; Write-Host "$script:ESC[30;43m $Message $script:ESC[0m"; Write-Host }
function Write-Success { param([string]$Message); Write-Section $Message }

# ─── Commit message via GitHub Models API ─────────────────────────────────────
function Get-CommitMsgViaApi {
    param([string]$diff, [string]$stats)

    $token = $env:GITHUB_TOKEN
    if (-not $token) { $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "User") }
    if (-not $token) { return $null }  # no token — skip silently, fall through to agent

    if ($diff.Length -gt $MAX_DIFF_CHARS) {
        $diff = $diff.Substring(0, $MAX_DIFF_CHARS) + "`n... [diff truncated]"
    }

    $systemPrompt = "You are an expert at writing git commit messages. Analyze the staged diff and write a single conventional commit message. Format: type(optional-scope): description. Allowed types: feat fix docs chore refactor test perf ci build style revert. Rules: lowercase type, lowercase description, max 100 chars total, single line, no trailing period. Return ONLY the commit message — no explanation, no quotes, no markdown."
    $userPrompt   = "Stats:`n$stats`n`nDiff:`n$diff"

    $body = @{
        model    = $AI_MODEL
        messages = @(
            @{ role = "system"; content = $systemPrompt }
            @{ role = "user";   content = $userPrompt }
        )
        temperature = 0.2
        max_tokens  = 80
    } | ConvertTo-Json -Depth 5 -Compress

    $headers = @{
        Authorization  = "Bearer $token"
        "Content-Type" = "application/json"
    }

    $attempt = 0
    $backoff  = @(5, 15, 30)
    $maxTries = 3

    while ($attempt -lt $maxTries) {
        try {
            $resp = Invoke-RestMethod -Uri $MODELS_URL -Method POST -Headers $headers -Body $body -TimeoutSec 20
            $raw  = $resp.choices[0].message.content.Trim()
            # Scan every line for a valid conventional commit (model sometimes adds preamble)
            foreach ($line in ($raw -split "`n")) {
                $line = $line.Trim()
                if ($line -match $COMMIT_PATTERN) { return $line }
            }
            return $null  # response came back but no valid line found
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -eq 401 -or $status -eq 403) {
                Write-Host "  GitHub API auth error ($status) — check GITHUB_TOKEN." -ForegroundColor DarkGray
                return $null
            }
            $attempt++
            if ($attempt -lt $maxTries) {
                $wait = $backoff[$attempt - 1]
                if ($status -eq 429) { $wait *= 2 }
                Write-Host "  API error — retrying in ${wait}s..." -ForegroundColor DarkGray
                Start-Sleep -Seconds $wait
            }
        }
    }
    return $null
}

# ─── Commit message via local `agent -f` (existing fallback) ──────────────────
function Get-CommitMsgViaAgent {
    param([string]$stats)

    if (-not (Get-Command agent -ErrorAction SilentlyContinue)) { return $null }

    $prompt = "Carefully analyze the currently staged changes in this git repository and write a correct conventional commit message based on changes/diff.

To see what changed, run: git diff --cached

Stats:
$stats

Format: type: description (single-line, lowercase type, lowercase description, max 100 chars)

Types: feat, fix, docs, chore, refactor, test, perf, ci, build, style, revert

Return ONLY the commit message, nothing else. Remember it must be single-line, lowercase type, lowercase description, max 100 chars."

    $promptFile = Join-Path $env:TEMP "commit_prompt.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8

    try {
        $output = agent -f $promptFile 2>&1
        $result = ($output | Select-Object -Skip 1 | Select-Object -First 1).Trim()
        if ($result -match $COMMIT_PATTERN) { return $result }
        return $null
    } catch {
        return $null
    } finally {
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }
}

# ─── Repository sanity checks ─────────────────────────────────────────────────
Write-Header "Checking Repository State..."
git rev-parse --git-dir 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Not in a git repository. Exiting..."
    exit 1
}

$conflicts = git status --porcelain | Select-String "^UU"
if ($conflicts) {
    Write-Err "Merge conflict in progress. Please resolve conflicts first. Exiting..."
    exit 1
}

git status -sb

# ─── Branch + upstream detection ──────────────────────────────────────────────
$currentBranch = git rev-parse --abbrev-ref HEAD
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    Write-Err "Could not determine current branch. Exiting..."
    exit 1
}

git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Info "No upstream configured. Skipping pull..."
    $hasUpstream = $false
} else {
    $hasUpstream = $true

    Write-Header "Pulling Remote Changes..."
    git pull
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Git pull failed with error $LASTEXITCODE. Exiting..."
        exit $LASTEXITCODE
    }
}

# ─── Stage all changes ────────────────────────────────────────────────────────
git add . 2>$null | Out-Null

# ─── Commit ───────────────────────────────────────────────────────────────────
$stagedFiles = git diff --cached --name-only
if ($stagedFiles) {

    Write-Header "Generating Commit Message..."

    $diff  = git diff --cached 2>$null | Out-String
    $stats = git diff --cached --stat | Out-String

    $commitMsg = $null
    $source    = $null

    # 1. Primary: GitHub Models API (gpt-4o-mini)
    Write-Host "  Trying GitHub Models API (gpt-4o-mini)..." -ForegroundColor DarkGray
    $commitMsg = Get-CommitMsgViaApi -diff $diff -stats $stats
    if ($commitMsg) { $source = "GitHub Models (gpt-4o-mini)" }

    # 2. Fallback: local `agent -f`
    if (-not $commitMsg) {
        Write-Host "  API unavailable — trying local agent..." -ForegroundColor Yellow
        $commitMsg = Get-CommitMsgViaAgent -stats $stats
        if ($commitMsg) { $source = "local agent" }
    }

    # 3. Last resort
    if (-not $commitMsg) {
        $commitMsg = "chore: update"
        $source    = "default fallback"
    }

    Write-Host "  Source: $source" -ForegroundColor DarkGray
    Write-Section "Making Commit..."
    Write-Info "Commit: $commitMsg"
    git commit -m $commitMsg
}

# ─── Push ─────────────────────────────────────────────────────────────────────
Write-Header "Checking for commits to push..."

$commitsToPush = 0
if ($hasUpstream) {
    $commitsToPush = git rev-list --count "@{u}..HEAD" 2>$null
} else {
    $commitsToPush = git rev-list --count HEAD 2>$null
}
if ([string]::IsNullOrWhiteSpace($commitsToPush)) { $commitsToPush = 0 }

if ($commitsToPush -eq 0) {
    Write-Section "No commits to push, skipping push step..."
} else {
    $remotes = git remote 2>$null
    if ([string]::IsNullOrWhiteSpace($remotes)) {
        Write-Section "No remote repository configured. Skipping push step..."
    } else {
        Write-Header "Pushing $commitsToPush commit(s)..."

        if (-not $hasUpstream) {
            git push -u origin $currentBranch
        } else {
            git push
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Err "Git push failed with error $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
}

# ─── Final state ──────────────────────────────────────────────────────────────
Write-Header "Final Repository State..."
$finalStatus = git status --porcelain

if ([string]::IsNullOrWhiteSpace($finalStatus)) {
    Write-Host; Write-Host "$ESC[30;42m CLEAN $ESC[0m"; Write-Host
} else {
    Write-Host; Write-Host "$ESC[37;41m UNCOMMITTED CHANGES REMAIN $ESC[0m"; Write-Host
}

Write-Success "DONE!"
