@echo off
REM Prepares Horizon's game files from your own Minecraft 26.3.
REM Run this once, and again only if an update asks for it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1"
if errorlevel 1 pause
