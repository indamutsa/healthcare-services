# Project Sync Hooks

## Dependency Management
```bash
# Auto-update package.json when requirements.txt changes
# Hook: on requirements.txt modification
pip install -r requirements.txt

# Auto-update requirements.txt when new Python packages installed
# Hook: after pip install
pip freeze > requirements.txt

# Auto-install npm dependencies when package.json changes
# Hook: on package.json modification
npm install
```

## Environment Sync
```bash
# Sync environment variables between .env files
# Frontend (.env.local) and Backend (.env)

# Auto-generate TypeScript types from API schemas
# Hook: after FastAPI schema changes
python scripts/generate_types.py

# Update README.md with new API endpoints
# Hook: after new routes added
python scripts/update_docs.py
```

## Development Workflow
- Automatic type generation on API changes
- Dependency synchronization
- Documentation updates
- Environment variable validation