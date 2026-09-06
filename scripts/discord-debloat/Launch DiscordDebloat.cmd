@echo off
title Discord Debloat Suite
cd /d "%~dp0"

rem -STA is required by WPF. Both hosts happen to default to STA today, but that is
rem a default, not a guarantee - state it explicitly.
where pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0DiscordDebloat.ps1" %*
) else (
    powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0DiscordDebloat.ps1" %*
)
