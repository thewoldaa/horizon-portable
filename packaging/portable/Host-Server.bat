@echo off
REM Hosts a Horizon server from a folder inside this package.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\server.ps1"
if errorlevel 1 pause
