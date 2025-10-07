# Deployment Commands

## Frontend Deployment
```bash
# Vercel deployment
npx vercel
npx vercel --prod

# Netlify deployment
npm run build
npx netlify deploy --prod --dir=out

# Docker build
docker build -t app-frontend .
docker run -p 3000:3000 app-frontend
```

## Backend Deployment
```bash
# Docker build
docker build -t app-backend .
docker run -p 8000:8000 app-backend

# Heroku deployment
heroku create app-name
git push heroku main

# Railway deployment
railway login
railway init
railway up
```

## Production Checks
```bash
# Pre-deployment validation
npm run build && npm run lint && npm run typecheck
pytest && python -m mypy app/
```