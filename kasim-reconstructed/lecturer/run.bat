@echo off
title Kasim Lecturer Web Portal
echo ========================================================
echo        Kasim Lecturer Web Portal (Teacher Dashboard)     
echo ========================================================
echo.

cd /d "%~dp0"
if not defined KASIM_API_URL set KASIM_API_URL=http://localhost:8000/api
echo Launching Flutter Web Server on Port 3000...
echo Accessible on ANY browser at: http://localhost:3000
echo.

flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0 --dart-define=KASIM_API_URL=%KASIM_API_URL% --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_CLIENT_ID%
pause
