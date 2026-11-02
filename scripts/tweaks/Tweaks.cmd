@echo off
REM Double-clicking a .ps1 opens it in an editor instead of running it, so this
REM launcher exists for that. With no arguments Tweaks.ps1 asks Windows for
REM elevation itself; -Apply, -Revert and -Status need an elevated prompt.
setlocal

set "PS=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tweaks.ps1" %*

REM Keep the window open if something went wrong, so the message is readable.
if errorlevel 1 pause
