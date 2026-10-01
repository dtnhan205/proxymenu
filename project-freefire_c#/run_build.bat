@echo off
chcp 65001 >nul
title Free Fire IFix Patch Builder
cd /d "%~dp0"
echo ========================================================
echo   BAT DAU BIEN DICH IFix Patch (project-freefire_c#)
echo ========================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
if %errorlevel% neq 0 (
    echo.
    echo [LOI] Bien dich that bai! Vui long kiem tra log o tren.
    pause
    exit /b %errorlevel%
)
echo.
echo ========================================================
echo   BIEN DICH THANH CONG!
echo   File output tai: dist\Assembly-CSharp-patch.bytes
echo ========================================================
echo.
pause
