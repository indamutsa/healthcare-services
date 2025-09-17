# Pre-commit Hooks

## Automatic Code Quality Checks
```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-yaml

  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black

  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.0.254
    hooks:
      - id: ruff

  - repo: local
    hooks:
      - id: typescript-check
        name: TypeScript Check
        entry: npm run typecheck
        language: system
        files: \.(ts|tsx)$
```

## Usage
- Runs automatically on `git commit`
- Fix issues before commit
- `pre-commit run --all-files` to check all files