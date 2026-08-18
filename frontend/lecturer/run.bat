@echo off
title Kasim Lecturer Web Portal
echo ========================================================
echo        Kasim Lecturer Web Portal (Teacher Dashboard)     
echo ========================================================
echo.

cd /d "%~dp0"
echo Launching Flutter Web Server on Port 3000...
echo Accessible on ANY browser at: http://localhost:3000
echo.

flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0
pause
