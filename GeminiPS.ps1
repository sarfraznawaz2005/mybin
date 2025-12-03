# Requires Glow for markdown formatting: https://github.com/charmbracelet/glow

param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$UserArgs
)

$Model = 'gemini-2.5-flash'
$GlowWidth = 120
$ErrorActionPreference = 'Continue'

# --- Optimized UTF-8 Setup with Early Return ---
$prevOutEnc = [Console]::OutputEncoding
$prevInEnc  = [Console]::InputEncoding
$prevPSOut  = $OutputEncoding

# Set UTF-8 encoding once
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
[Console]::InputEncoding  = $utf8NoBom
$OutputEncoding = $utf8NoBom

# Optimized Unicode environment setup
$env:PYTHONIOENCODING = 'utf-8'
$env:LC_ALL = 'C.UTF-8'
$env:LANG = 'en_US.UTF-8'

# --- System Prompt ---
$SYSTEM = @'
ROLE: Expert personal assistant running inside PowerShell, specialized in automating tasks on Windows 11.

## Core Capabilities

- Multi-shell expertise (bash, zsh, PowerShell, cmd)
- Advanced command chaining, piping, and scripting (bash, Python, PowerShell, PHP)
- System diagnostics with performance/log analysis
- Secure, integrity-focused operations

## Operating Principles

1. **Environment Check** – Detect OS, shell, and available tools before executing.
2. **Strategic Execution** – Break tasks into verifiable, self-contained steps.
3. **Tool Selection Rules**:
   - Prefer native commands over external tools where possible.
   - For Windows, default to PowerShell over cmd.
   - Always check if a tool is installed before use.
4. **Safety & Verification**:
   - Use idempotent commands when possible.
   - Verify critical paths, files, and permissions before making changes.
   - Avoid destructive or elevated operations unless explicitly approved.
5. **Efficiency & Adaptation** – Adjust commands dynamically based on output or errors.

## Available Tools

- Gemini CLI
- PowerShell
- Windows 11 built-ins
- cygwin64 utilities
- PHP, NodeJS, ffmpeg, etc.

## RULES YOU MUST FOLLOW

1. **Scope & Tools**  
   - All user requests are about automation or Windows tasks in the current folder's context.  
   - Use only shell commands or relevant local tools. Do not use Google search unless the request is explicitly unrelated to automation or Windows.  

2. **Safety**  
   - Never delete, overwrite, or modify existing files, folders, or directories unless the user explicitly authorizes it in the same request.  
   - All actions must be non-destructive and fully reversible. You may create new files or folders.  

3. **Assumptions**  
   - Do not ask questions; make reasonable, context-aware assumptions based on the given task.

4. **Response Structure & Style**  
   - Always start with `# PLAN` in markdown, followed by a numbered list so the user can undo steps if needed.  
   - Style: concise, numbered, reproducible, markdown format only.  
   - Use bold, italics, headings (`#`), and markdown tables where appropriate.  
   - Insert one blank line after every heading and before any list item or paragraph.
   
5. **Output Requirements**
   - Always begin your answer on a new line.
   - Prefer tabular answer in OUTPUT if possible.
   - **CRITICAL: DO NOT repeat the PLAN or EXECUTION sections.** Your response must be linear and progressive. Once a step is planned or executed, move on to the next. Do not loop or restate previous steps.

## Output Format:

# PLAN:

1. Sample step 1
2. Sample step 2
3. Sample step 3

# EXECUTION:

1. Using x tool for step 1
2. Using y tool for step 2
3. Using z tool for step 3

# OUTPUT:

{Your final answer here.}

'@

# --- Optimized Helper Functions ---
function Write-FileUtf8NoBom {
  param([string]$Path, [string]$Content)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Test-HttpError {
  param([string]$Text)
  if ($Text -match '(?i)("code"\s*:\s*|status(?:\s*code)?\D{0,5})(?<code>\d{3})') {
    return [int]$matches.code
  }
  if ($Text -match '(?i)"status"\s*:\s*"Too\s*Many\s*Requests"|RESOURCE_EXHAUSTED') {
    return 429
  }
  return $null
}

function Write-GeminiError {
  param([string]$ErrorText)
  $status = Test-HttpError $ErrorText
  $msg = if ($status -eq 429) { "You have exhausted your quota, please try again later." } else { $ErrorText }
  Write-Host $msg -ForegroundColor Red
}

function Set-ConsoleUtf8 {
  try { 
    $null = cmd /c "chcp 65001 2>nul" 
    $env:GLOW_PAGER = 'never'
    $env:GLOW_STYLE = 'auto'
  } catch { 
    # Ignore if not supported 
  }
}

function Restore-ConsoleSettings {
  param($OutEnc, $InEnc, $PSOut)
  try {
    if ($OutEnc) { [Console]::OutputEncoding = $OutEnc }
    if ($InEnc)  { [Console]::InputEncoding = $InEnc }
    if ($PSOut)  { $OutputEncoding = $PSOut }
  } catch { }
}

function Invoke-GlowRender {
  param([string]$FilePath)
  
  $glowExe = 'glow.exe'
  
  if ($glowExe) {
    Set-ConsoleUtf8
    try {
      & $glowExe -w $GlowWidth $FilePath
    } catch {
      Write-Host "Error running glow: $_" -ForegroundColor Red
      Get-Content -Path $FilePath -Encoding UTF8 | Write-Host
    }
  } else {
    Write-Host "[Info] glow not found. Output saved at:`n$FilePath"
    Write-Host "[Info] Content preview:" -ForegroundColor Yellow
    Get-Content -Path $FilePath -Encoding UTF8 -TotalCount 10 | Write-Host
  }
}

# --- Main Execution ---
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$userRequest = [string]::Join(' ', $UserArgs)

# Create payload
$payload = @"
Today Date & Time: $timestamp

$SYSTEM

---

USER REQUEST:
$userRequest
"@

# Generate unique temp files
$randomId = Get-Random
$promptFile = Join-Path $env:TEMP "gemini_prompt_$randomId.txt"
$outputFile = Join-Path $env:TEMP "gemini_output_$randomId.md"

try {
  # Write prompt to file
  Write-FileUtf8NoBom -Path $promptFile -Content $payload

  # Execute gemini with piped input
	Get-Content -Path $promptFile -Encoding UTF8 -Raw |
	  & gemini --model $Model --yolo 2>$null |
	  Tee-Object -FilePath $outputFile |
	  Out-Host

    # Fix encoding for PS 5.1
    $content = Get-Content -LiteralPath $outputFile -Raw -Encoding UTF8
    Write-FileUtf8NoBom -Path $outputFile -Content $content

  # Check for errors
  if ($LASTEXITCODE -ne 0) {
    $errorContent = Get-Content -LiteralPath $outputFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-GeminiError ("Gemini exited with code $LASTEXITCODE. $errorContent")
    exit $LASTEXITCODE
  }
} catch {
  Write-GeminiError "Failed to run gemini: $($_.Exception.Message)"
  exit 1
} finally {
  # Cleanup prompt file
  if (Test-Path $promptFile) {
    Remove-Item $promptFile -Force -ErrorAction SilentlyContinue
  }
}

# Optimize markdown content
$content = Get-Content -LiteralPath $outputFile -Raw -Encoding UTF8

# Single-pass content normalization
$content = $content.TrimStart([char]0xFEFF) # Remove BOM if present  

Write-FileUtf8NoBom -Path $outputFile -Content $content

Clear-Host

# Render output
Invoke-GlowRender -FilePath $outputFile

# Restore console settings
Restore-ConsoleSettings -OutEnc $prevOutEnc -InEnc $prevInEnc -PSOut $prevPSOut