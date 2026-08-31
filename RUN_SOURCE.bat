@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo ==========================================
echo  Ultimate Macro - Source Checkout Setup
echo ==========================================
echo.
echo Preparing verified OCR/JSON dependencies...

if not exist "tools\sync_dependencies.ps1" (
    echo.
    echo ERROR: tools\sync_dependencies.ps1 is missing.
    echo Download the official TDS_Macro.zip from GitHub Releases.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\tools\sync_dependencies.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: verified dependency setup failed.
    echo.
    pause
    exit /b 1
)

if not exist "lib\OCR.ahk" (
    echo ERROR: lib\OCR.ahk was not materialized.
    pause
    exit /b 1
)

if not exist "lib\JSON.ahk" (
    echo ERROR: lib\JSON.ahk was not materialized.
    pause
    exit /b 1
)

echo.
echo Dependencies verified.
echo Starting Ultimate Macro...
echo.

if exist "submacros\AutoHotkey64.exe" (
    start "" "%CD%\submacros\AutoHotkey64.exe" "%CD%\Main.ahk"
    exit /b 0
)

start "" "%CD%\Main.ahk"
exit /b 0
