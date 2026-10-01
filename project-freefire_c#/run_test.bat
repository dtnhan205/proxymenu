@echo off
chcp 65001 >nul
title Free Fire IFix Patch Tester
cd /d "%~dp0"
echo ========================================================
echo   BAT DAU KIEM THU (project-freefire_c#)
echo ========================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1
if %errorlevel% neq 0 (
    echo.
    echo [LOI] Kiem thu that bai!
    pause
    exit /b %errorlevel%
)
echo.
echo ========================================================
echo   KIEM THU THANH CONG 100%!
echo ========================================================
echo.
pause
