@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\ApkStart-Hebrew.ps1"
if errorlevel 1 (
  echo.
  echo ApkStart-Hebrew could not start. See the error above.
  pause
)
