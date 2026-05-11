@echo off
title Hyperion Optimizer Launcher
color 0A

:: Check for Administrative Privileges (Optimizer needs this to manage CPU/RAM)
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administrator Privileges Confirmed.
) else (
    echo [WAIT] Requesting Administrator Privileges...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

echo.
echo ===================================================
echo      HYPERION MULTI-INSTANCE OPTIMIZER LAUNCHER
echo ===================================================
echo.
echo Starting the PowerShell Optimizer Engine...

:: Navigate to the script location (now in the same folder) and run it
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HyperionOptimizer.ps1"

echo.
echo Optimizer has stopped.
pause
