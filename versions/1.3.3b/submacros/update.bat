@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul
cd %temp%

for /f "delims=#" %%E in ('"prompt #$E# & for %%E in (1) do rem"') do set "\e=%%E"
set cyan=%\e%[96m
set green=%\e%[92m
set purple=%\e%[95m
set red=%\e%[91m
set yellow=%\e%[93m
set reset=%\e%[0m

if [%1]==[] (
    exit /b 1
)

set "DOWNLOAD_URL=%~1"
set "MACRO_DIR=%~2"
set "ZIP_PATH=%temp%\tds_update.zip"

if not exist "%MACRO_DIR%" (
    echo %red%Macro folder not found: %MACRO_DIR%%reset%
    pause
    exit /b 1
)

echo %cyan%Downloading update...%reset%
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%DOWNLOAD_URL%', '%ZIP_PATH%')"
if not exist "%ZIP_PATH%" (
    echo %red%Download failed!%reset%
    pause
    exit /b 1
)
echo %cyan%Download complete!%reset%
echo:

echo %yellow%Cleaning old macro files...%reset%
set RETRIES=0
:clean_retry
del /f /s /q "%MACRO_DIR%\*" >nul 2>&1
for /d %%p in ("%MACRO_DIR%\*") do rd /s /q "%%p" >nul 2>&1

dir /b "%MACRO_DIR%" 2>nul | findstr . >nul && (
    set /a RETRIES+=1
    if !RETRIES! lss 10 (
        timeout /t 2 >nul
        goto clean_retry
    ) else (
        echo %red%Failed to clean folder after 10 attempts. Aborting.%reset%
        pause
        exit /b 1
    )
)
echo %green%Folder cleaned.%reset%
echo:

echo %purple%Extracting new version directly to %MACRO_DIR%...%reset%
powershell -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%MACRO_DIR%' -Force"
echo %purple%Extract complete!%reset%
echo:

del /f /q "%ZIP_PATH%" 2>nul

echo %green%Update completed! Starting TDS Macro...%reset%
timeout /t 2 >nul

if exist "%MACRO_DIR%\Main.ahk" (
    start "" "%MACRO_DIR%\Main.ahk"
) else if exist "%MACRO_DIR%\ultimate_macro.exe" (
    start "" "%MACRO_DIR%\ultimate_macro.exe"
)

exit /b 0
