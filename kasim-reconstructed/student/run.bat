@echo off
title Kasim Student Desktop Client
echo ========================================================
echo        Kasim Student Windows Desktop Client              
echo ========================================================
echo.

cd /d "%~dp0"
if not defined KASIM_API_URL set KASIM_API_URL=http://localhost:8000/api
echo Launching Flutter Windows Desktop Client...
flutter run -d windows --dart-define=KASIM_API_URL=%KASIM_API_URL%
pause
