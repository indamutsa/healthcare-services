#!/bin/bash
# Quick project setup script for full-stack development

echo "🚀 Setting up development environment..."

# Create common directories
mkdir -p {components,pages,api,types,utils,styles,tests}

# Frontend setup
if [ ! -f "package.json" ]; then
    echo "📦 Initializing frontend..."
    npm init -y
    npm install next react react-dom typescript @types/react @types/node
    npm install -D tailwindcss eslint prettier
fi

# Backend setup  
if [ ! -f "requirements.txt" ]; then
    echo "🐍 Setting up Python backend..."
    cat > requirements.txt << EOF
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
sqlalchemy==2.0.23
python-multipart==0.0.6
EOF
fi

# Environment files
if [ ! -f ".env.example" ]; then
    cat > .env.example << EOF
# Database
DATABASE_URL=sqlite:///./app.db

# API
API_URL=http://localhost:8000
NEXT_PUBLIC_API_URL=http://localhost:8000

# Auth (if needed)
SECRET_KEY=your-secret-key-here
EOF
fi

# TypeScript config
if [ ! -f "tsconfig.json" ]; then
    cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{"name": "next"}],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
fi

echo "✅ Setup complete! Run './claude/scripts/dev_check.sh' to verify."