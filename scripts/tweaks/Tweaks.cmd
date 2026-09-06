@echo off
REM Double-clicking a .ps1 opens it in an editor instead of running it, so this
REM launcher exists for that. Tweaks.ps1 asks Windows for elevation itself.
setlocal

set "PS=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tweaks.ps1" %*

REM Keep the window open if something went wrong, so the message is readable.
if errorlevel 1 pause
