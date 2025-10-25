# Model Serving & Level 4 ML Pipeline - Fixes Summary

## Issues Fixed

### 1. Missing middleware `__init__.py`
**Problem**: Missing `__init__.py` in `middleware/` directory caused import errors
**Fix**: Created `/applications/model-serving/middleware/__init__.py`
**Status**: ✅ Fixed

### 2. MLflow Server Network Binding Issue
**Problem**: MLflow was binding to `127.0.0.1:5000` instead of `0.0.0.0:5000`, making it inaccessible from other containers
**Root Cause**: The `--host 0.0.0.0` flag was being ignored by MLflow/uvicorn
**Fix**: Added `GUNICORN_CMD_ARGS` environment variable to docker-compose.yml:
```yaml
environment:
  GUNICORN_CMD_ARGS: "--bind 0.0.0.0:5000 --workers 4 --timeout 120"
```
**Verification**:
```bash
# MLflow now shows:
[INFO] Listening at: http://0.0.0.0:5000 (23)

# Accessible from Docker network:
docker run --rm --network clinical-trials-service_mlops-network python:3.11-slim \
  python -c "import urllib.request; print(urllib.request.urlopen('http://mlflow-server:5000/health').read())"
# Returns: b'OK'
```
**Status**: ✅ Fixed

### 3. MLflow Health Check Using curl
**Problem**: Health check used `curl` which isn't available in `python:3.11-slim` image
**Fix**: Updated health check to use Python's built-in urllib:
```yaml
healthcheck:
  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()"]
```
**Status**: ✅ Fixed

### 4. MLflow Port Mapping Mismatch
**Problem**: External port 5050 was mapped to internal 5050, but MLflow runs on 5000
**Fix**: Corrected port mapping in docker-compose.yml:
```yaml
ports:
  - "5050:5000"  # External:Internal
```
**Status**: ✅ Fixed

### 5. Health Check Script Quoting Issues
**Problem**: Bash quoting errors in `scripts/ml-layer/health-checks.sh`
**Fix**: Escaped quotes properly in docker exec commands:
```bash
docker exec mlflow-server python -c \"import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()\"
```
**Status**: ✅ Fixed

## Current State

### ✅ Working Services
- **mlflow-server**: Running and healthy, accessible on:
  - Internal: `http://mlflow-server:5000`
  - External: `http://localhost:5050`
- **Level 4 Management Scripts**: Fully functional with cascading dependencies
- **Health Checks**: All connectivity checks passing

### ⚠️ Model-Serving Expected Behavior
**Status**: Container exits with code 3
**Reason**: No model registered in MLflow yet
**Error**:
```
mlflow.exceptions.RestException: RESOURCE_DOES_NOT_EXIST:
Registered Model with name=adverse-event-predictor not found
```

**This is EXPECTED behavior** - model-serving requires a trained model to be registered in MLflow before it can start.

## Workflow Order

To bring up a fully functional Level 4 stack:

```bash
# 1. Start Level 4 (MLflow will start, model-serving will fail)
./pipeline-manager.sh --start --level 4

# 2. Run training to create and register a model
./pipeline-manager.sh --run-training --level 4

# 3. Once training completes, restart model-serving
docker compose restart model-serving

# 4. Verify both services are healthy
./pipeline-manager.sh --health-check --level 4
```

## Files Modified

1. `/workspaces/clinical-trials-service/docker-compose.yml`
   - Fixed mlflow-server network binding (GUNICORN_CMD_ARGS)
   - Fixed health check (Python urllib instead of curl)
   - Fixed port mapping (5050:5000)

2. `/workspaces/clinical-trials-service/applications/model-serving/middleware/__init__.py`
   - Created missing init file

3. `/workspaces/clinical-trials-service/scripts/ml-layer/health-checks.sh`
   - Fixed quoting in docker exec commands

4. `/workspaces/clinical-trials-service/infrastructure/docker/mlflow/start-mlflow.sh`
   - Created (not currently used, but available for custom startup logic)

## Testing Commands

```bash
# Check Level 4 status
./pipeline-manager.sh --summary --level 4

# Run health checks
./pipeline-manager.sh --health-check --level 4

# Test MLflow from Docker network
docker run --rm --network clinical-trials-service_mlops-network python:3.11-slim \
  python -c "import urllib.request; print(urllib.request.urlopen('http://mlflow-server:5000/health').read())"

# Check MLflow logs
docker logs mlflow-server | grep "Listening"

# Check model-serving logs
docker logs model-serving
```

## Next Steps

1. ✅ MLflow health check passing
2. ⏳ Run training job to register first model
3. ⏳ Restart model-serving after model registration
4. ⏳ Verify full Level 4 stack operational

## Key Insights

1. **MLflow Binding**: The `--host` flag alone isn't sufficient; `GUNICORN_CMD_ARGS` is needed to ensure proper network binding
2. **Model-Serving Design**: The application fails-fast on startup if no model exists, which is good for catching configuration issues but requires training to run first
3. **Health Checks**: Using Python stdlib for health checks is more reliable than external tools in slim containers
4. **Level 4 Scripts**: Already well-designed with proper cascading dependency management

## Production Recommendations

Consider making model-serving more resilient:
- Add a graceful fallback if no model is registered
- Implement retry logic with exponential backoff during startup
- Add a `/ready` endpoint separate from `/health` to distinguish between "service running" and "model loaded"
- Document the startup order requirements clearly

---

**Status**: Level 4 infrastructure fully functional. Model-serving awaits first training run.
