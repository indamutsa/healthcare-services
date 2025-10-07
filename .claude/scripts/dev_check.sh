#!/bin/bash
# Development environment health check script

echo "🔍 Running development environment checks..."

# Check Node.js and npm
if command -v node &> /dev/null; then
    echo "✅ Node.js: $(node --version)"
else
    echo "❌ Node.js not installed"
fi

if command -v npm &> /dev/null; then
    echo "✅ npm: $(npm --version)"
else
    echo "❌ npm not installed"
fi

# Check Python and pip
if command -v python3 &> /dev/null; then
    echo "✅ Python: $(python3 --version)"
else
    echo "❌ Python3 not installed"
fi

if command -v pip &> /dev/null; then
    echo "✅ pip: $(pip --version)"
else
    echo "❌ pip not installed"
fi

# Check project dependencies
if [ -f "package.json" ]; then
    echo "📦 Frontend dependencies:"
    if [ -d "node_modules" ]; then
        echo "✅ node_modules exists"
    else
        echo "⚠️  node_modules missing - run 'npm install'"
    fi
fi

if [ -f "requirements.txt" ]; then
    echo "📦 Backend dependencies:"
    echo "⚠️  Check with 'pip list' manually"
fi

# Check for environment files
if [ -f ".env" ]; then
    echo "✅ .env file exists"
else
    echo "⚠️  .env file missing"
fi

if [ -f ".env.local" ]; then
    echo "✅ .env.local file exists"
else
    echo "⚠️  .env.local file missing"
fi

# Check Git status
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "✅ Git repository"
    echo "📊 Status: $(git status --porcelain | wc -l) modified files"
else
    echo "❌ Not a Git repository"
fi

echo "✨ Health check complete!"