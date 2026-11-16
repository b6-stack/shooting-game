@echo off
setlocal
echo ==========================================================
echo   ShootingGame - Deploy to Samsung Galaxy S24+ / Android
echo ==========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0push_to_s24.ps1"
if errorlevel 1 (
    echo.
    echo Deployment encountered an issue. See details above.
    pause
)
