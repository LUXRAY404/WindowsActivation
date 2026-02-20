@echo off
title Advanced BitLocker Decryption Tool
setlocal enabledelayedexpansion

:: ===== ANSI Color Setup =====
:: Check if ANSI colors are supported (Windows 10+ with VT enabled)
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
if defined ESC (
    set "red=!ESC![91m"
    set "green=!ESC![92m"
    set "yellow=!ESC![93m"
    set "blue=!ESC![94m"
    set "magenta=!ESC![95m"
    set "cyan=!ESC![96m"
    set "white=!ESC![97m"
    set "gray=!ESC![90m"
    set "reset=!ESC![0m"
    set "bold=!ESC![1m"
) else (
    :: Fallback to no colors
    set "red="
    set "green="
    set "yellow="
    set "blue="
    set "magenta="
    set "cyan="
    set "white="
    set "gray="
    set "reset="
    set "bold="
)

:: ===== Admin Check =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo !red!Requesting Administrator Privileges...!reset!
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    exit /b
)

cls
:: ===== Stylish Header =====
echo !cyan!!bold!╔══════════════════════════════════════════════════════════╗!reset!
echo !cyan!!bold!║       Advanced BitLocker Decryption Tool (Styled)       ║!reset!
echo !cyan!!bold!╚══════════════════════════════════════════════════════════╝!reset!
echo.

:: ===== Check BitLocker availability =====
manage-bde -? >nul 2>&1
if errorlevel 1 (
    echo !red!BitLocker Drive Encryption is not available on this system.!reset!
    echo !yellow!Please ensure you are running a supported Windows edition (Pro/Enterprise).!reset!
    pause
    exit /b
)

:: ===== Drive Selection =====
:getdrive
echo !white!Enter the drive letter to decrypt (e.g., C): !reset!
set /p "drive=> "

if "!drive!"=="" (
    echo !red!No drive entered. Exiting...!reset!
    pause
    exit /b
)

:: Normalize drive letter
set "drive=!drive::=!"
set "drive=!drive:~0,1!"
if not exist !drive!:\nul (
    echo !red!Drive !drive!: does not exist or is not accessible.!reset!
    goto getdrive
)

:: ===== Display current status =====
cls
echo !cyan!!bold!╔══════════════════════════════════════════════════════════╗!reset!
echo !cyan!!bold!║         Current BitLocker Status for Drive !drive!:         ║!reset!
echo !cyan!!bold!╚══════════════════════════════════════════════════════════╝!reset!
echo.
manage-bde -status !drive!: | findstr /b /c:"Conversion Status:" /c:"Percentage Encrypted:" /c:"Encryption Method:" /c:"Protection Status:" /c:"Key Protectors:"
echo.

:: Confirmation
set /p "confirm=!yellow!Are you sure you want to decrypt !drive!:? This may take a long time. (Y/N): !reset!"
if /i not "!confirm!"=="Y" (
    echo !red!Decryption cancelled.!reset!
    pause
    exit /b
)

:: Clear auto-unlock keys
echo !blue!Clearing stored auto-unlock keys...!reset!
manage-bde -autounlock -ClearAllKeys !drive!:
if errorlevel 1 echo !yellow!Warning: Failed to clear auto-unlock keys (may not exist).!reset!

:: Start decryption
echo !blue!Starting decryption...!reset!
manage-bde -off !drive!:
if errorlevel 1 (
    echo !red!Failed to start decryption. Check BitLocker status.!reset!
    pause
    exit /b
)

echo !green!Decryption process initiated successfully!!reset!
echo.
echo !magenta!╔══════════════════════════════════════════════════════════╗!reset!
echo !magenta!║            Live Decryption Monitor Started             ║!reset!
echo !magenta!║      Press Ctrl+C to stop monitoring (decryption       ║!reset!
echo !magenta!║                continues in background)                ║!reset!
echo !magenta!╚══════════════════════════════════════════════════════════╝!reset!
echo.

:: ===== Live Monitoring Loop =====
:monitor
:: Get encryption percentage
for /f "tokens=2 delims=:" %%a in ('manage-bde -status !drive!: ^| findstr /r /c:"Percentage Encrypted:[ ]*[0-9,.]*"') do set "raw=%%a"
set "raw=!raw: =!"
set "percent=!raw:%%=!"
if "!percent!"=="" set percent=0
set "percent=!percent:,=!"

cls
:: Dynamic title
title BitLocker Decryption - Drive !drive!: !percent!%% Encrypted

:: Header with progress color
echo !cyan!!bold!╔══════════════════════════════════════════════════════════╗!reset!
echo !cyan!!bold!║                 BitLocker Decryption Progress           ║!reset!
echo !cyan!!bold!╚══════════════════════════════════════════════════════════╝!reset!
echo.
echo !white!Drive: !cyan!!drive!:!!reset!
set /a done=100-!percent!
if !done! lss 0 set done=0
if !done! gtr 100 set done=100
echo !white!Completed: !green!!done!%%!reset!  !white!Remaining: !yellow!!percent!%%!reset!
echo.

:: ===== Colored Progress Bar =====
set "bar="
set /a barwidth=50
for /f "usebackq tokens=2 delims=:" %%a in (`mode con ^| findstr /i "columns"`) do set /a barwidth=%%a-25 2>nul
if !barwidth! lss 10 set barwidth=50
if !barwidth! gtr 100 set barwidth=100

set /a filled=!done! * !barwidth! / 100
set /a empty=!barwidth! - !filled!

:: Build bar with colors: filled part in green, empty in gray
for /l %%i in (1,1,!filled!) do set "bar=!bar!!green!█!reset!"
for /l %%i in (1,1,!empty!) do set "bar=!bar!!gray!░!reset!"

echo !white!Progress: !bar! !green!!done!%%!reset!
echo.

:: Additional status
echo !white!Current Status:!reset!
manage-bde -status !drive!: | findstr /b /c:"Conversion Status:" /c:"Protection Status:" /c:"Lock Status:"
echo.

if "!percent!"=="0" (
    echo.
    echo !green!!bold!╔══════════════════════════════════════════════════════════╗!reset!
    echo !green!!bold!║         Decryption Completed Successfully!              ║!reset!
    echo !green!!bold!╚══════════════════════════════════════════════════════════╝!reset!
    echo.
    pause
    exit /b
)

timeout /t 5 /nobreak >nul
goto monitor
