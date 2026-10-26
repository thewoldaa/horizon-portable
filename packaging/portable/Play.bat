@echo off
REM Starts Horizon. Every world, setting and mod stays in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play.ps1" %*
if errorlevel 1 pause
