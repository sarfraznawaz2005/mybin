@echo off
for /f %%a in ('echo prompt $E^| cmd') do set "CYAN=%%a"

echo %CYAN%[36m----------------------------------------%CYAN%[0m
echo %CYAN%[36mHello%CYAN%[0m
echo %CYAN%[36m----------------------------------------%CYAN%[0m
