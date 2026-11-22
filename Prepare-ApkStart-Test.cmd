@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Prepare-Manual-Test.ps1"
if errorlevel 1 (
  echo.
  echo Test preparation failed. See the error above.
  pause
)
