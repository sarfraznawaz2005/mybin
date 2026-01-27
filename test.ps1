# test.ps1 - Demonstrate styled headings in PowerShell

Write-Host "\n=== Heading 1: Default ===" -ForegroundColor White
Write-Host "\n=== Heading 2: Blue BG, White FG ===" -ForegroundColor White -BackgroundColor Blue
Write-Host "\n=== Heading 3: Green BG, Black FG ===" -ForegroundColor Black -BackgroundColor Green
Write-Host "\n=== Heading 4: Red BG, Yellow FG ===" -ForegroundColor Yellow -BackgroundColor Red
Write-Host "\n=== Heading 5: Cyan BG, Black FG ===" -ForegroundColor Black -BackgroundColor Cyan
Write-Host "\n=== Heading 6: Magenta BG, White FG ===" -ForegroundColor White -BackgroundColor Magenta
Write-Host "\n=== Heading 7: Underlined (simulated) ===" -ForegroundColor White
Write-Host "------------------------------" -ForegroundColor White
Write-Host "\n=== Heading 8: Double Underline (simulated) ===" -ForegroundColor White
Write-Host "=============================" -ForegroundColor White
Write-Host "\n=== Heading 9: Boxed (simulated) ===" -ForegroundColor Yellow
Write-Host "+--------------------------+" -ForegroundColor Yellow
Write-Host "|   Boxed Heading Style   |" -ForegroundColor Yellow
Write-Host "+--------------------------+" -ForegroundColor Yellow
Write-Host "\n=== Heading 10: Bold (simulated with asterisks) ===" -ForegroundColor White
Write-Host "*** BOLD HEADING ***" -ForegroundColor White
Write-Host "\n=== Heading 11: Italic (simulated with slashes) ===" -ForegroundColor White
Write-Host "/ Italic Heading /" -ForegroundColor White
Write-Host "\n=== Heading 12: Mixed Colors ===" -ForegroundColor Yellow -BackgroundColor Blue
Write-Host "\nChoose your preferred style for your project!" -ForegroundColor Green
Write-Host "iam done, exit...."
