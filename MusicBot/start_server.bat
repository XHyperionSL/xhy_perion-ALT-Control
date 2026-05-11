@echo off
title Hyperion Music Bot Server
color 0B

echo ================================================================
echo     Hyperion Music Bot Server
echo     Credits: @xhy_perion
echo     Discord: https://discord.gg/kfxRmYzp3t
echo ================================================================
echo.

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH.
    echo [INFO]  Run install_dependencies.bat first.
    pause
    exit /b 1
)

:: Check required packages
python -c "import flask, flask_cors, yt_dlp, pygame" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Missing Python packages.
    echo [INFO]  Run install_dependencies.bat first.
    pause
    exit /b 1
)

:: Create storage if missing
if not exist "storage\cache" mkdir "storage\cache"

echo Starting Music Bot Server...
echo Press Ctrl+C to stop the server.
echo.

python server.py

echo.
echo Server stopped.
pause
