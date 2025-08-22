@echo off
chcp 65001 >nul
setlocal

call php artisan optimize:clear || goto :err
call composer require sarfraznawaz2005/aiqueryoptimizer:dev-main --prefer-source --no-interaction || goto :err
call php artisan vendor:publish --provider="AIQueryOptimizer\AIQueryOptimizerServiceProvider" --force || goto :err

echo ✅ All done.
pause
exit /b 0

:err
echo ❌ Failed with errorlevel %errorlevel%.
pause
exit /b %errorlevel%
