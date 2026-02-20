@echo off
title Advanced BitLocker Decryption Tool
color 0A

:: ===== Admin Check =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator Privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    exit
)

cls
echo ===============================================
echo        Advanced BitLocker Disable Tool
echo ===============================================
echo.

:: ===== Select Drive =====
set /p drive=Enter drive letter to decrypt (Example: C): 

if "%drive%"=="" (
    echo No drive entered. Exiting...
    pause
    exit
)

echo.
echo Checking BitLocker status on %drive%:
manage-bde -status %drive%:
echo.

echo Clearing stored auto-unlock keys...
manage-bde -autounlock -ClearAllKeys %drive%:
echo.

echo Starting decryption...
manage-bde -off %drive%:
echo.

echo ===============================================
echo Live Decryption Monitor Started
echo Press CTRL+C to exit monitoring
echo ===============================================
echo.

:: ===== Live Monitoring Loop =====
:monitor
for /f "tokens=3" %%A in ('manage-bde -status %drive% ^| find "Percentage Encrypted"') do set percent=%%A
set percent=%percent:~0,-1%

cls
echo ===============================================
echo      BitLocker Decryption Progress
echo ===============================================
echo.
echo Drive: %drive%:
echo Remaining Encrypted: %percent%%
echo.

:: ===== Progress Bar =====
setlocal enabledelayedexpansion
set /a done=100-%percent%
set "bar="
for /l %%B in (1,1,!done!) do set "bar=!bar!#"
echo Progress:
echo [!bar!]
endlocal

echo.
manage-bde -status %drive% | find "Conversion Status"
echo.

if "%percent%"=="0" (
    echo ===============================================
    echo     Decryption Completed Successfully!
    echo ===============================================
    pause
    exit
)

timeout /t 10 >nul
goto monitor
