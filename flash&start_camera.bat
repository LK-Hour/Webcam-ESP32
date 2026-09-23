@echo off
setlocal

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\flash_and_start.ps1"
if errorlevel 1 (
    echo.
    echo Flash and start did not finish. See the error above.
    pause
    exit /b 1
)
