# Clinical MLOps Pipeline - Level-Based Management System

## 📋 Overview

This new management system provides **clean level-based control** where:
- **Start by level**: Only starts services for that specific level (with dependencies)
- **Stop by level**: Removes containers (and optionally volumes) for that level only
- **Clean all**: Removes EVERYTHING from docker-compose (containers, volumes, networks, images)

## 🔧 Required Changes

### 1. Update docker-compose.yml

**Move MLflow from Level 0 to Level 4:**

**REMOVE** the mlflow-server section from around line 187-217 (in Level 0 Infrastructure section)

**ADD** the mlflow-server with profile to Level 4 (ML Pipeline section):

```yaml
  # ============================================================================
  # LEVEL 4: ML PIPELINE (Profile: ml-pipeline)
  # ============================================================================
  
  mlflow-server:
    image: python:3.11-slim
    container_name: mlflow-server
    depends_on:
      postgres-mlflow:
        condition: service_healthy
      minio:
        condition: service_healthy
    ports:
      - "5050:5050"
    environment:
      MLFLOW_S3_ENDPOINT_URL: http://minio:9000
      AWS_ACCESS_KEY_ID: minioadmin
      AWS_SECRET_ACCESS_KEY: minioadmin
    networks:
      - mlops-network
    command: >
      bash -c "
      pip install mlflow boto3 psycopg2-binary &&
      mlflow server 
        --backend-store-uri postgresql://mlflow:mlflow@postgres-mlflow:5432/mlflow 
        --default-artifact-root s3://mlflow-artifacts/ 
        --host 0.0.0.0 
        --port 5000
      "
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
    profiles:
      - ml-pipeline    # 👈 THIS IS THE KEY ADDITION

  ml-training:
    # ... rest of config ...
    profiles:
      - training
      - ml-pipeline    # 👈 Add this

  model-serving:
    # ... rest of config ...
    profiles:
      - serving
      - ml-pipeline    # 👈 Add this
```

### 2. Add the management script

Copy `manage_pipeline.sh` to your project root and make it executable:

```bash
chmod +x manage_pipeline.sh
```

## 📊 Level Architecture

### Level 0: Infrastructure
**Services**: minio, minio-setup, postgres-mlflow, postgres-airflow, redis, redis-insight, zookeeper, kafka, kafka-ui

**Dependencies**: None

**What it provides**: Core infrastructure (storage, databases, messaging, caching)

**❌ NO LONGER INCLUDES**: mlflow-server (moved to Level 4)

### Level 1: Data Ingestion
**Services**: kafka-producer, kafka-consumer, clinical-mq, clinical-data-gateway, lab-results-processor, clinical-data-generator

**Dependencies**: Level 0

**What it does**: Ingests data from various sources into Kafka and stores raw data in MinIO

### Level 2: Data Processing
**Services**: spark-master, spark-worker, spark-streaming, spark-batch

**Dependencies**: Levels 0, 1

**What it does**: Processes raw data using Spark, creates Silver layer (cleaned/validated data)

### Level 3: Feature Engineering
**Services**: feature-engineering

**Dependencies**: Levels 0, 1, 2

**What it does**: Generates features from processed data, stores in offline (MinIO) and online (Redis) stores

### Level 4: ML Pipeline
**Services**: ✨ **mlflow-server**, ml-training, model-serving

**Dependencies**: Levels 0, 3

**What it does**: Trains models, tracks experiments, serves predictions

**✨ NEW**: MLflow server now starts at Level 4, not Level 0

### Level 5: Orchestration
**Services**: airflow-init, airflow-webserver, airflow-scheduler

**Dependencies**: Level 0

**What it does**: Orchestrates workflows, schedules batch processing, feature syncs, and model retraining

**Status**: ✅ Production

### Level 6: Observability
**Services**: prometheus, grafana, monitoring-service, opensearch, opensearch-dashboards, data-prepper, filebeat

**Dependencies**: Level 0

**What it does**: Monitors and provides visibility into the entire pipeline

**Status**: 🚧 In Progress

### Level 7: Platform Engineering
**Services**: argocd, github-actions-runner, istio, argo-rollouts

**Dependencies**: Level 0

**What it does**: Provides GitOps workflows, CI/CD automation, service mesh, and progressive delivery

**Status**: 📋 Planned

### Level 8: Security Testing
**Services**: metasploit, burp-suite, owasp-zap, trivy, sonarqube

**Dependencies**: Level 0

**What it does**: Automated security testing, vulnerability scanning, and penetration testing

**Status**: 📋 Planned

## 🚀 Usage Examples

### Basic Operations

```bash
# Start infrastructure only
./manage_pipeline.sh --start-level 0

# Start data ingestion (auto-starts Level 0)
./manage_pipeline.sh --start-level 1

# Start ML Pipeline (auto-starts Levels 0, 1, 2, 3, and MLflow)
./manage_pipeline.sh --start-level 4

# Show status of all levels
./manage_pipeline.sh --status

# View logs for specific level
./manage_pipeline.sh --logs 2
```

### Stop Operations

```bash
# Stop Level 2 (keeps volumes - data persists)
./manage_pipeline.sh --stop-level 2

# Stop Level 3 (removes volumes too - clean slate)
./manage_pipeline.sh --stop-level-full 3

# Stop all levels (keeps volumes)
./manage_pipeline.sh --stop-full
```

### Clean Operations

```bash
# ⚠️ NUCLEAR OPTION: Remove EVERYTHING from docker-compose
# This removes: containers, volumes, networks, AND images
./manage_pipeline.sh --clean-all
```

## 🎯 Key Behaviors

### 1. Dependency Auto-Start
When you start a level, all its dependencies automatically start:

```bash
# Starting Level 4 automatically starts:
# - Level 0 (infrastructure)
# - Level 1 (data ingestion)
# - Level 2 (data processing)
# - Level 3 (feature engineering)
# - Level 4 (ML pipeline with MLflow)
./manage_pipeline.sh --start-level 4
```

### 2. Isolated Stop
Stopping a level ONLY affects that level, not its dependencies:

```bash
# Stops ONLY Level 2 services
# Levels 0, 1, 3, 4, 5 remain running
./manage_pipeline.sh --stop-level 2
```

### 3. Volume Preservation
By default, stopping preserves data:

```bash
# Stops containers but keeps volumes
./manage_pipeline.sh --stop-level 3

# Stops containers AND removes volumes
./manage_pipeline.sh --stop-level-full 3
```

### 4. Full Clean
The nuclear option that removes EVERYTHING:

```bash
# Removes ALL docker-compose resources:
# - All containers (stopped and running)
# - All volumes (data is LOST)
# - All networks
# - All images defined in docker-compose
./manage_pipeline.sh --clean-all
```

## 📝 Command Reference

```bash
# Start operations
--start-level <N>      # Start level N and dependencies (N = 0-8)
--start-full           # Start all levels (0-8)

# Stop operations
--stop-level <N>       # Stop level N (keep volumes)
--stop-level-full <N>  # Stop level N (remove volumes)
--stop-full            # Stop all levels (keep volumes)

# Other operations
--restart-level <N>    # Restart level N
--logs <N>             # Follow logs for level N
--status               # Show status of all levels
--clean-all            # Remove EVERYTHING

# Help
--help                 # Show full help message
```

## ⚠️ Important Notes

### MLflow Server Change
**OLD BEHAVIOR** (Level 0):
```bash
./manage_pipeline.sh --start-level 0  # ✅ Started MLflow
```

**NEW BEHAVIOR** (Level 4):
```bash
./manage_pipeline.sh --start-level 0  # ❌ Does NOT start MLflow
./manage_pipeline.sh --start-level 4  # ✅ Starts MLflow
```

### Why This Change?
- **Separation of concerns**: Infrastructure (Level 0) vs ML tooling (Level 4)
- **Resource efficiency**: Don't start MLflow if you're only testing data ingestion
- **Logical grouping**: MLflow belongs with training and serving, not with Kafka and Redis

### Data Persistence
- `--stop-level`: Keeps volumes → **Data persists** → Can restart quickly
- `--stop-level-full`: Removes volumes → **Data is lost** → Clean slate
- `--clean-all`: Removes EVERYTHING → **Complete reset** → Like starting fresh

## 🔍 Troubleshooting

### Check what's running
```bash
./manage_pipeline.sh --status
```

### View logs for specific level
```bash
./manage_pipeline.sh --logs 3
```

### Restart a stuck level
```bash
./manage_pipeline.sh --restart-level 2
```

### Complete reset
```bash
./manage_pipeline.sh --clean-all
./manage_pipeline.sh --start-level 0
```

## 🎨 Status Output Colors

- **Green ✓**: Service is running
- **Red ✗**: Service is stopped
- **Yellow**: Warning or in-progress operation
- **Cyan**: Level headers and informational text
- **Blue**: Starting/transitional states

## 📊 Typical Workflows

### Development Workflow
```bash
# Start infrastructure
./manage_pipeline.sh --start-level 0

# Test data ingestion
./manage_pipeline.sh --start-level 1
./manage_pipeline.sh --logs 1

# Add data processing
./manage_pipeline.sh --start-level 2
./manage_pipeline.sh --logs 2

# Test features
./manage_pipeline.sh --start-level 3

# Train model
./manage_pipeline.sh --start-level 4
```

### Testing Workflow
```bash
# Start full stack
./manage_pipeline.sh --start-full

# Check status
./manage_pipeline.sh --status

# Monitor specific level
./manage_pipeline.sh --logs 4

# Stop and clean when done
./manage_pipeline.sh --stop-full
```

### Production-like Workflow
```bash
# Start all levels except observability
./manage_pipeline.sh --start-level 4

# Add observability
./manage_pipeline.sh --start-level 5

# Check everything
./manage_pipeline.sh --status
```

## 🔗 Access Points

After starting services, access them at:

- **MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)
- **Kafka UI**: http://localhost:8090
- **MLflow UI**: http://localhost:5000 (Level 4 only)
- **Redis UI**: http://localhost:5540
- **Spark Master**: http://localhost:8080
- **Model API**: http://localhost:8000
- **Airflow UI**: http://localhost:8081 (admin/admin) - Level 5
- **Prometheus**: http://localhost:9090 - Level 6
- **Grafana**: http://localhost:3000 (admin/admin) - Level 6
- **OpenSearch**: http://localhost:5601 - Level 6
- **ArgoCD**: http://localhost:8082 (planned) - Level 7

## ✅ Benefits of This System

1. **Granular Control**: Start/stop only what you need
2. **Resource Efficient**: Don't run unnecessary services
3. **Clear Dependencies**: Explicit level dependencies
4. **Data Safety**: Choose to keep or remove volumes
5. **Clean Separation**: Each level has clear responsibilities
6. **Easy Cleanup**: Nuclear option available when needed
7. **Better Testing**: Test levels in isolation

## 🎯 Next Steps

1. Update your docker-compose.yml as described above
2. Add manage_pipeline.sh to your project root
3. Make it executable: `chmod +x manage_pipeline.sh`
4. Test basic operations: `./manage_pipeline.sh --start-level 0`
5. Verify MLflow is NOT running at Level 0
6. Start Level 4 and verify MLflow starts
7. Test cleanup: `./manage_pipeline.sh --clean-all`