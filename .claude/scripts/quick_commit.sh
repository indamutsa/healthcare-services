#!/bin/bash
# Quick commit script with automated checks

# Check if there are any changes
if [ -z "$(git status --porcelain)" ]; then
    echo "🔍 No changes to commit"
    exit 0
fi

echo "🔍 Pre-commit checks..."

# Frontend checks
if [ -f "package.json" ]; then
    echo "📝 Running TypeScript check..."
    if command -v npm &> /dev/null && npm run typecheck &> /dev/null; then
        echo "✅ TypeScript OK"
    else
        echo "⚠️  TypeScript check failed or not configured"
    fi
    
    echo "🧹 Running linter..."
    if npm run lint &> /dev/null; then
        echo "✅ Lint OK"
    else
        echo "⚠️  Lint check failed or not configured"
    fi
fi

# Backend checks
if [ -f "requirements.txt" ]; then
    echo "🐍 Python syntax check..."
    if command -v python3 &> /dev/null; then
        python3 -m py_compile **/*.py 2>/dev/null && echo "✅ Python syntax OK" || echo "⚠️  Python syntax issues"
    fi
fi

# Get commit message
echo "💬 Enter commit message:"
read -r commit_message

if [ -z "$commit_message" ]; then
    echo "❌ Commit message required"
    exit 1
fi

# Stage and commit
git add .
git commit -m "$commit_message"

echo "✅ Committed: $commit_message"