@echo off
title Kasim FastAPI Backend Server
echo ========================================================
echo           Kasim Secure Exam Platform Backend             
echo ========================================================
echo.

cd /d "%~dp0"

if exist .venv\Scripts\activate.bat (
    echo Activating Python Virtual Environment...
    call .venv\Scripts\activate.bat
) else if exist venv\Scripts\activate.bat (
    echo Activating legacy Python Virtual Environment...
    call venv\Scripts\activate.bat
) else (
    echo [Warning] Virtual environment not found. Attempting global Python run...
)

echo.
echo Starting FastAPI application server on port 8000...
echo Swagger API Docs: http://localhost:8000/docs
echo ========================================================
echo.

uvicorn app.main:app --reload --port 8000
pause
