@echo off
REM Development startup script for Windows

echo.
echo Starting FactPilot development environment...
echo.

REM Check if .env.local exists
if not exist .env.local (
    echo Creating .env.local from example...
    copy .env.local.example .env.local
    echo.
    echo Please edit .env.local with your OAuth credentials
    echo.
    pause
)

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo Python not found - please install Python 3.12+
    pause
    exit /b 1
)

REM Check Node
node --version >nul 2>&1
if errorlevel 1 (
    echo Node.js not found - please install Node.js 18+
    pause
    exit /b 1
)

REM Create virtual environment
if not exist venv (
    echo Creating Python virtual environment...
    python -m venv venv
)

REM Activate venv and install deps
call venv\Scripts\activate.bat
echo Installing Python dependencies...
pip install -q -r requirements.txt

REM Install Node deps
if not exist frontend\node_modules (
    echo Installing Node dependencies...
    cd frontend
    call npm install
    cd ..
)

echo.
echo All dependencies installed!
echo.
echo Starting services...
echo   - Backend:  http://localhost:8000
echo   - Frontend: http://localhost:3000
echo   - API Docs: http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop all services
echo.

REM Start backend
start "Backend" cmd /c "venv\Scripts\activate.bat && python -m uvicorn src.api.main:app --reload --port 8000"

REM Wait a bit for backend to start
timeout /t 3 /nobreak >nul

REM Start frontend
start "Frontend" cmd /c "cd frontend && npm run dev"

echo.
echo Services started in separate windows!
echo Close the windows or press Ctrl+C to stop.
echo.
pause
