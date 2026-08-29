@echo off
setlocal
chcp 65001 >nul

rem Backwards-compatible wrapper. All updates go through safe_update.ps1.
rem The former delete-first updater is intentionally gone.

if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1
if "%~3"=="" exit /b 1
if "%~4"=="" exit /b 1

set "DOWNLOAD_URL=%~1"
set "MACRO_DIR=%~2"
set "EXPECTED_SHA256=%~3"
set "EXPECTED_VERSION=%~4"
set "WAIT_PID=%~5"

if not defined WAIT_PID set "WAIT_PID=0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0safe_update.ps1" ^
  -DownloadUrl "%DOWNLOAD_URL%" ^
  -MacroDir "%MACRO_DIR%" ^
  -ExpectedSha256 "%EXPECTED_SHA256%" ^
  -ExpectedVersion "%EXPECTED_VERSION%" ^
  -WaitPid %WAIT_PID%

exit /b %ERRORLEVEL%
