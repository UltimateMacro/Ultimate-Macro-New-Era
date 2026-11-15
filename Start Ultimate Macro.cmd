@echo off
setlocal
cd /d "%~dp0"
start "" /d "%~dp0" "%~dp0submacros\AutoHotkey64.exe" "%~dp0Main.ahk"
