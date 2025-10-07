# Development Setup Commands

## Frontend Setup
```bash
# Next.js project initialization
npx create-next-app@latest --typescript --tailwind --eslint --app

# Install common dependencies
npm install @types/node @types/react @types/react-dom
npm install -D prettier eslint-config-prettier

# Start development
npm run dev
```

## Backend Setup
```bash
# FastAPI project initialization
pip install fastapi uvicorn[standard] python-multipart
pip install sqlalchemy alembic pydantic-settings

# Create requirements.txt
pip freeze > requirements.txt

# Start development
uvicorn main:app --reload
```

## Full Stack Setup
```bash
# Install both frontend and backend dependencies
npm install && pip install -r requirements.txt

# Run both servers concurrently
npm run dev & uvicorn main:app --reload
```