@echo off
title Build Kasim Student Windows Release Package
echo ========================================================
echo   Compiling Kasim Student Desktop Release Executable     
echo ========================================================
echo.

cd /d "%~dp0"
echo Running: flutter build windows --release
call flutter build windows --release

echo.
echo ========================================================
echo Build Output Location:
echo %~dp0build\windows\x64\runner\Release\
echo ========================================================
pause
