# Requires: GitHub CLI (winget install GitHub.cli). Run once:  gh auth login

#How to Use:
#
# Login: gh auth login (choose HTTPS, your account, and grant repo scope)
# release.bat 1.0.18 main

# make-release.ps1
param(
  [Parameter(Mandatory=$true)] [string]$Tag,          # e.g. v1.0.18
  [string]$Target = "main"                             # branch/commit to tag
)

# Title will be the same as Tag
$Title = $Tag

# 1) Create an annotated tag locally (skip if tag already exists)
if (-not (git tag --list $Tag)) {
  git tag -a $Tag -m $Title $Target
}
git push origin $Tag

# 2) Figure out previous tag for compare link
$PrevTag = (git describe --tags --abbrev=0 "$Tag^") 2>$null

$Repo = gh repo view --json nameWithOwner -q '.nameWithOwner'

# 3) Generate notes
$bodyArgs = @("-f", "tag_name=$Tag")
if ($PrevTag) { $bodyArgs += @("-f", "previous_tag_name=$PrevTag") }

$GeneratedNotes = gh api --method POST `
  "repos/:owner/:repo/releases/generate-notes" `
  $bodyArgs -q '.body'

# 4) Create or update release
if (gh release view $Tag *> $null) {
  gh release edit $Tag --title "$Title" --notes $GeneratedNotes --latest
} else {
  gh release create $Tag --title "$Title" --notes $GeneratedNotes --latest
}

Write-Host "✅ Release $Tag published for $Repo."

