# MLflow Server Health Check Fix

## Problem
The `mlflow-server` container health check was failing, preventing Level 4 (ML Pipeline) from starting properly.

**Root Causes:**
1. Health check used `curl` command, but the `python:3.11-slim` base image doesn't include curl
2. Port mapping mismatch: external port 5050 was mapped to internal 5050, but MLflow runs on internal port 5000

## Solution

### 1. Fixed Health Check (Line 537)
**Before:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
```

**After:**
```yaml
healthcheck:
  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()"]
```

**Benefits:**
- Uses Python's built-in `urllib.request` library (no external dependencies)
- Works with slim Python images
- More reliable and consistent with the container's base image

### 2. Fixed Port Mapping (Line 520)
**Before:**
```yaml
ports:
  - "5050:5050"
```

**After:**
```yaml
ports:
  - "5050:5000"
```

**Explanation:**
- MLflow server runs on internal port 5000 (specified in command: `--port 5000`)
- External port 5050 is mapped to internal port 5000
- Other services connect internally via `http://mlflow-server:5000`
- External access via `http://localhost:5050`

## Verification

### Test the Health Check Locally
```bash
# Start only mlflow-server dependencies
docker compose up -d postgres-mlflow minio

# Start mlflow-server
docker compose up -d mlflow-server

# Watch health status
watch 'docker compose ps mlflow-server'

# Should show "healthy" status after ~30 seconds
```

### Test with Pipeline Manager
```bash
# Start Level 4 (ML Pipeline)
./pipeline-manager.sh --start --level 4

# Check health
./pipeline-manager.sh --health-check --level 4

# Verify status
./pipeline-manager.sh --summary --level 4
```

## Impact

**Services Fixed:**
- ✅ mlflow-server now passes health checks
- ✅ ml-training can now start (depends on mlflow-server health)
- ✅ model-serving can now start (depends on mlflow-server health)
- ✅ Level 4 stack can fully start

**Files Modified:**
- `docker-compose.yml` (2 lines changed)

## Related Services

The following services depend on mlflow-server being healthy:
1. `ml-training` - Requires `mlflow-server: condition: service_healthy`
2. `model-serving` - Requires `mlflow-server: condition: service_healthy`

Both will now start correctly once mlflow-server passes its health check.
