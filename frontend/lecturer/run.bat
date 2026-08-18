@echo off
title Kasim Lecturer Web Portal
echo ========================================================
echo        Kasim Lecturer Web Portal (Teacher Dashboard)     
echo ========================================================
echo.

cd /d "%~dp0"
echo Launching Flutter Web App on Chrome (Port 3000)...
flutter run -d chrome --web-port 3000
pause
