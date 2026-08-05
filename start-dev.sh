#!/bin/bash
# Development startup script - Run both backend and frontend locally

set -e

echo "🚀 Starting FactPilot development environment..."
echo ""

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo "⚠️  .env.local not found - creating from example..."
    cp .env.local.example .env.local
    echo "✅ Created .env.local - please edit with your OAuth credentials"
    echo ""
fi

# Check Python
if ! command -v python &> /dev/null; then
    echo "❌ Python not found - please install Python 3.12+"
    exit 1
fi

# Check Node
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found - please install Node.js 18+"
    exit 1
fi

# Check virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python -m venv venv
    echo "✅ Virtual environment created"
fi

# Activate venv
source venv/bin/activate 2>/dev/null || source venv/Scripts/activate 2>/dev/null

# Install Python deps
echo "📦 Installing Python dependencies..."
pip install -q -r requirements.txt

# Install Node deps
if [ ! -d "frontend/node_modules" ]; then
    echo "📦 Installing Node dependencies..."
    cd frontend && npm install && cd ..
fi

echo ""
echo "✅ All dependencies installed!"
echo ""
echo "🔧 Starting services..."
echo "   - Backend:  http://localhost:8000"
echo "   - Frontend: http://localhost:3000"
echo "   - API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Start backend in background
python -m uvicorn src.api.main:app --reload --port 8000 &
BACKEND_PID=$!

# Wait for backend to start
sleep 3

# Start frontend
cd frontend
npm run dev &
FRONTEND_PID=$!

# Wait for Ctrl+C
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT TERM

wait
