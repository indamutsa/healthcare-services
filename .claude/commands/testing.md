# Testing Commands

## Frontend Testing
```bash
# Jest + React Testing Library
npm install -D jest @testing-library/react @testing-library/jest-dom

# Run tests
npm test
npm run test:watch
npm run test:coverage

# E2E with Playwright
npx playwright install
npx playwright test
```

## Backend Testing
```bash
# pytest setup
pip install pytest pytest-asyncio httpx

# Run tests
pytest
pytest -v
pytest --cov=app
pytest -k "test_specific"

# FastAPI test client
pytest tests/test_main.py::test_read_main
```

## Full Stack Testing
```bash
# Run all tests
npm test && pytest

# CI pipeline testing
npm run build && npm test && pytest
```