@echo off
title Kasim Student Desktop Client
echo ========================================================
echo        Kasim Student Windows Desktop Client              
echo ========================================================
echo.

cd /d "%~dp0"
echo Launching Flutter Windows Desktop Client...
flutter run -d windows
pause
