@echo off
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

start /wait cmd /c "o git pull, status, add, diff to make commit message then commit and finally push followed by git status again for verification. For making up commit message, try to find out core stuff that was changed by seeing diffs and make commit message based on that. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). After pushing, you MUST verify the operation by running 'git status' again to confirm the branch is up to date with the origin. && pause"

:: using these manual commands to verify AI actually did push
echo %ESC%[92m-- AI Operation Verification --%ESC%[0m

git status
git push

