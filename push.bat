@echo off
for /f %%a in ('echo prompt $E^| cmd') do (
  set "ESC=%%a"
)

git pull
git status
git add .

start /wait cmd /c "ok Make git commit message. For making up commit message, try to find out core stuff that was changed by seeing diffs and make commit message based on that. The commit message must be a single line starting with a conventional commit prefix (feat, fix, docs, chore, etc.). Finally git commit. && pause"

git status
git push 

:: using these manual commands to verify AI actually did push
echo %ESC%[92m-- AI Operation Verification --%ESC%[0m

git status
git push
