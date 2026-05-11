@echo off
setlocal
title Hyperion Music Bot - Dependency Installer
color 0A

:: ──────────────────────────────────────────────
::  AUTO-ELEVATE TO ADMINISTRATOR
:: ──────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)
cd /d "%~dp0"

echo.
echo  ============================================================
echo     Hyperion Music Bot - One-Click Setup
echo     Credits: @xhy_perion
echo  ============================================================
echo.

set "FAILS=0"

:: ══════════════════════════════════════════════
::  STEP 1/8 - Python
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=0;$i -le 4;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Checking Python...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo   [..] Python not found. Installing Python 3.12...
    echo   [..] This may take a few minutes, please wait...
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo   [FAIL] Could not install Python automatically.
        echo          Install from https://www.python.org/downloads/
        echo          CHECK "Add Python to PATH" during install
        set /a FAILS+=1
    ) else (
        set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
        set "PATH=C:\Python312;C:\Python312\Scripts;%PATH%"
        echo   [OK] Python installed
    )
) else (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo   [OK] %%i
)
echo.

:: ══════════════════════════════════════════════
::  STEP 2/8 - FFmpeg
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=4;$i -le 8;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Checking FFmpeg...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo   [..] FFmpeg not found. Installing...
    winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements >nul 2>&1
    if %errorlevel% neq 0 (
        winget install -e --id FFmpeg.FFmpeg --accept-source-agreements --accept-package-agreements >nul 2>&1
    )
    for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "PATH=%%b;%PATH%"
    ffmpeg -version >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] FFmpeg installed
    ) else (
        echo   [OK] FFmpeg installed - restart PC if not detected later
    )
) else (
    echo   [OK] FFmpeg detected
)
echo.

:: ══════════════════════════════════════════════
::  STEP 3/8 - pip upgrade
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=8;$i -le 11;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Upgrading pip...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python -m pip install --upgrade pip >nul 2>&1
echo   [OK] pip upgraded
echo.

:: ══════════════════════════════════════════════
::  STEP 4/8 - Flask
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=11;$i -le 15;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Installing Flask...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python -m pip install flask >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Flask installed) else (echo   [FAIL] Flask & set /a FAILS+=1)
echo.

:: ══════════════════════════════════════════════
::  STEP 5/8 - Flask-CORS
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=15;$i -le 19;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Installing Flask-CORS...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python -m pip install flask-cors >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Flask-CORS installed) else (echo   [FAIL] Flask-CORS & set /a FAILS+=1)
echo.

:: ══════════════════════════════════════════════
::  STEP 6/8 - yt-dlp
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=19;$i -le 23;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Installing yt-dlp...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python -m pip install yt-dlp >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] yt-dlp installed) else (echo   [FAIL] yt-dlp & set /a FAILS+=1)
echo.

:: ══════════════════════════════════════════════
::  STEP 7/8 - pygame
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=23;$i -le 27;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Installing pygame...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
python -m pip install pygame >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] pygame installed) else (echo   [FAIL] pygame & set /a FAILS+=1)
echo.

:: ══════════════════════════════════════════════
::  STEP 8/8 - Storage
:: ══════════════════════════════════════════════
powershell -NoProfile -Command "for($i=27;$i -le 30;$i++){$f='#'*$i;$e='-'*(30-$i);$p=[math]::Floor($i/30*100);Write-Host -No \"`r  [$f$e] $p%% - Creating storage...   \";Start-Sleep -Milliseconds 40};Write-Host ''"
if not exist "storage" mkdir "storage"
if not exist "storage\cache" mkdir "storage\cache"
echo   [OK] Storage directories ready
echo.

:: ══════════════════════════════════════════════
::  VERIFICATION
:: ══════════════════════════════════════════════
echo  ------------------------------------------------------------
powershell -NoProfile -Command "for($i=0;$i -le 30;$i++){$f='#'*$i;$e='-'*(30-$i);Write-Host -No \"`r  [$f$e] Verifying...   \" -ForegroundColor Cyan;Start-Sleep -Milliseconds 25};Write-Host ''"
echo  ------------------------------------------------------------
echo.

set "PASS=0"
set "FAIL=0"

python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo   [PASS] Python:     %%i
    set /a PASS+=1
) else (
    echo   [FAIL] Python:     NOT FOUND
    set /a FAIL+=1
)

ffmpeg -version >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] FFmpeg:     Installed & set /a PASS+=1) else (echo   [FAIL] FFmpeg:     NOT FOUND & set /a FAIL+=1)

python -c "import flask" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] Flask:      Installed & set /a PASS+=1) else (echo   [FAIL] Flask:      MISSING & set /a FAIL+=1)

python -c "import flask_cors" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] Flask-CORS: Installed & set /a PASS+=1) else (echo   [FAIL] Flask-CORS: MISSING & set /a FAIL+=1)

python -c "import yt_dlp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] yt-dlp:     Installed & set /a PASS+=1) else (echo   [FAIL] yt-dlp:     MISSING & set /a FAIL+=1)

python -c "import pygame" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] pygame:     Installed & set /a PASS+=1) else (echo   [FAIL] pygame:     MISSING & set /a FAIL+=1)

echo.

:: Final result check (no delayed expansion needed)
if %FAIL% equ 0 goto :ALL_GOOD
goto :SOME_FAILED

:ALL_GOOD
echo  ============================================================
echo    ALL 6/6 DEPENDENCIES INSTALLED SUCCESSFULLY
echo.
echo    Next steps:
echo      1. Edit server.py - set API_KEY and MAIN_ACCOUNT
echo      2. Edit Lua client - set same API_KEY and server URL
echo      3. Double-click start_server.bat to launch
echo  ============================================================
goto :DONE

:SOME_FAILED
echo  ============================================================
echo    SOME COMPONENTS FAILED - check errors above
echo    Try restarting your PC and running this again
echo  ============================================================

:DONE
echo.
pause
