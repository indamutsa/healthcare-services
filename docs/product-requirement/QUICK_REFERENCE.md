# Quick Reference Guide

## 📚 Command Migration Reference

### Old vs New Commands

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `./manage_pipeline.sh --start-level 0` | `./pipeline-manager.sh start infrastructure` | More readable |
| `./manage_pipeline.sh --start-level 1` | `./pipeline-manager.sh start data-ingestion` | Auto-starts dependencies |
| `./manage_pipeline.sh --start-level 4` | `./pipeline-manager.sh start ml-layer` | Auto-starts 0→1→2→3 |
| `./manage_pipeline.sh --stop-level 2` | `./pipeline-manager.sh stop processing-layer` | Cascade stops 2→1→0 |
| `./manage_pipeline.sh --status` | `./pipeline-manager.sh status` | Shows all layers |
| `./manage_pipeline.sh --start-level-rebuild 2` | `./pipeline-manager.sh rebuild processing-layer` | Stop→Build→Start |
| `./manage_pipeline.sh --logs 2` | `./pipeline-manager.sh logs processing-layer` | Follow layer logs |
| `./manage_pipeline.sh --start-full` | `./pipeline-manager.sh start-all` | Start everything |
| `./manage_pipeline.sh --stop-full` | `./pipeline-manager.sh stop-all` | Stop everything |
| `./manage_pipeline.sh --clean-all` | `./pipeline-manager.sh clean` | Nuclear option |

### Level to Layer Mapping

| Old Level | New Layer | Services |
|-----------|-----------|----------|
| Level 0 | infrastructure | minio, postgres, redis, kafka |
| Level 1 | data-ingestion | kafka-producer, kafka-consumer, clinical-* |
| Level 2 | processing-layer | spark-master, spark-worker, spark-* |
| Level 3 | ml-layer (part 1) | feature-engineering |
| Level 4 | ml-layer (part 2) | mlflow-server, ml-training, model-serving |
| Level 5a | orchestration-layer | airflow-* |
| Level 5b | observability | prometheus, grafana, opensearch, filebeat |

---

## 🔧 Common Patterns

### Pattern 1: Starting a Layer Directly

```bash
# Each layer can be started independently
./infrastructure/manage.sh start

# Or through the orchestrator (recommended)
./pipeline-manager.sh start infrastructure
```

### Pattern 2: Checking Layer Health

```bash
# Direct health check
./infrastructure/health-checks.sh

# Or through orchestrator
./pipeline-manager.sh health infrastructure
```

### Pattern 3: Cascade Operations

```bash
# Stop ml-layer and all its dependencies
./pipeline-manager.sh stop ml-layer
# Stops: ml-layer → processing-layer → data-ingestion → infrastructure

# Start ml-layer (auto-starts dependencies)
./pipeline-manager.sh start ml-layer
# Starts: infrastructure → data-ingestion → processing-layer → ml-layer
```

### Pattern 4: Layer-Specific Operations

```bash
# Infrastructure layer
./infrastructure/init-minio.sh          # Create buckets
./infrastructure/init-postgres.sh       # Initialize databases
./infrastructure/init-kafka.sh          # Create topics

# Data ingestion layer
./data-ingestion/kafka-setup.sh         # Configure Kafka
./data-ingestion/validators.sh          # Validate data quality

# Processing layer
./processing-layer/job-submit.sh        # Submit Spark job
./processing-layer/monitoring.sh        # Monitor job status

# ML layer
./ml-layer/feature-setup.sh             # Initialize feature store
./ml-layer/mlflow-setup.sh              # Configure MLflow
./ml-layer/model-ops.sh                 # Model operations

# Storage layer
./storage/bucket-ops.sh                 # Bucket CRUD
./storage/data-lifecycle.sh             # Bronze→Silver→Gold
```

---

## 📝 Code Templates

### Template 1: Adding a New Layer

```bash
#!/bin/bash
# Layer: my-new-layer
# Purpose: Description of what this layer does

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"
source "${SCRIPT_DIR}/../common/config.sh"

LAYER_NAME="my-new-layer"

# Initialize layer
init_layer() {
    log_section "Initializing ${LAYER_NAME}"
    # Add initialization logic here
}

# Validate dependencies
validate_dependencies() {
    local deps=$(get_layer_dependencies "$LAYER_NAME")
    for dep in $deps; do
        if ! check_layer_healthy "$dep"; then
            log_error "Dependency $dep is not healthy"
            return 1
        fi
    done
    return 0
}

# Health checks
health_check() {
    log_section "Health check for ${LAYER_NAME}"
    # Add health check logic here
}

# Start layer
start_layer() {
    local force_recreate=${1:-false}
    
    log_section "Starting ${LAYER_NAME}"
    
    validate_dependencies || return 1
    
    local services=$(get_layer_services "$LAYER_NAME")
    local profile=$(get_layer_profile "$LAYER_NAME")
    
    docker_compose_up "$services" "$profile" "$force_recreate"
    wait_for_services "$services" 90
    
    init_layer
    health_check
    
    log_success "${LAYER_NAME} started successfully"
}

# Stop layer
stop_layer() {
    local remove_volumes=${1:-false}
    
    log_section "Stopping ${LAYER_NAME}"
    
    local services=$(get_layer_services "$LAYER_NAME")
    docker_compose_down "$services" "$remove_volumes"
    
    log_success "${LAYER_NAME} stopped"
}

# Status
status_layer() {
    log_section "${LAYER_NAME} Status"
    
    local services=$(get_layer_services "$LAYER_NAME")
    display_services_status "$services"
}

# Command router
case "${1:-}" in
    start)
        start_layer false
        ;;
    start-force)
        start_layer true
        ;;
    stop)
        stop_layer false
        ;;
    stop-full)
        stop_layer true
        ;;
    status)
        status_layer
        ;;
    health)
        health_check
        ;;
    init)
        init_layer
        ;;
    *)
        echo "Usage: $0 {start|start-force|stop|stop-full|status|health|init}"
        exit 1
        ;;
esac
```

### Template 2: Adding Layer to Configuration

```bash
# In common/config.sh

# Add to layer definitions
LAYER_SERVICES[my-new-layer]="service1 service2 service3"
LAYER_PROFILES[my-new-layer]="my-profile"
LAYER_NAMES[my-new-layer]="My New Layer"
LAYER_DEPENDENCIES[my-new-layer]="infrastructure data-ingestion"
LAYER_FOLDERS[my-new-layer]="my-new-layer"

# Add to layer order
LAYER_ORDER=(
    "infrastructure"
    "data-ingestion"
    "storage"
    "processing-layer"
    "ml-layer"
    "my-new-layer"          # <-- Add here
    "orchestration-layer"
    "observability"
)
```

---

## 🐛 Troubleshooting Cheatsheet

### Issue: Dependency not starting

```bash
# Check dependency status
./pipeline-manager.sh status infrastructure

# Check specific service
docker ps | grep minio

# View logs
docker compose logs minio -f

# Restart dependency
./infrastructure/manage.sh restart
```

### Issue: Service health check failing

```bash
# Run health checks directly
./infrastructure/health-checks.sh

# Check service endpoints
curl http://localhost:9000/minio/health/live  # MinIO
curl http://localhost:5001/health             # MLflow
curl http://localhost:8081/health             # Airflow

# Check Docker network
docker network ls
docker network inspect clinical-mlops-pipeline_default
```

### Issue: Port conflicts

```bash
# Find process using port
lsof -i :5432   # PostgreSQL
lsof -i :9000   # MinIO
lsof -i :9092   # Kafka

# Stop conflicting service
sudo kill -9 <PID>

# Or change port in docker-compose.yml
```

### Issue: Volumes not persisting

```bash
# List volumes
docker volume ls | grep clinical

# Inspect volume
docker volume inspect clinical-mlops-pipeline_postgres-mlflow-data

# Remove volumes (⚠️ DATA LOSS)
./pipeline-manager.sh stop-all --remove-volumes
```

---

## 📊 Useful One-Liners

```bash
# Show all running services
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Follow logs for specific layer
./pipeline-manager.sh logs infrastructure

# Restart specific service
docker compose restart minio

# Execute command in container
docker exec -it minio bash

# Check MinIO buckets
docker exec minio mc ls local/

# Check Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Check Redis keys
docker exec redis redis-cli keys '*'

# Check PostgreSQL databases
docker exec postgres-mlflow psql -U mlflow -c '\l'

# View Spark cluster status
curl http://localhost:8080  # Spark Master UI

# View MLflow experiments
curl http://localhost:5001/api/2.0/mlflow/experiments/list

# Check Airflow DAGs
curl http://localhost:8081/api/v1/dags

# Query Prometheus metrics
curl 'http://localhost:9090/api/v1/query?query=up'
```

---

## 🔍 Debugging Strategies

### Strategy 1: Isolate the Layer

```bash
# 1. Stop everything
./pipeline-manager.sh stop-all

# 2. Start only the problematic layer's dependencies
./pipeline-manager.sh start infrastructure  # If data-ingestion is failing

# 3. Try starting the problematic layer
./data-ingestion/manage.sh start

# 4. Check logs immediately
docker compose logs kafka-consumer -f
```

### Strategy 2: Verify Dependencies

```bash
# Check each dependency manually
./infrastructure/health-checks.sh

# Verify service connectivity
docker exec kafka-consumer ping kafka
docker exec spark-master ping minio
```

### Strategy 3: Progressive Rollback

```bash
# If something breaks after changes:

# 1. Stop broken layer
./pipeline-manager.sh stop <broken-layer>

# 2. Check if dependencies still work
./pipeline-manager.sh status

# 3. Restart with force recreate
./pipeline-manager.sh rebuild <broken-layer>
```

---

## 📖 Reading Order for New Developers

For someone joining the project:

1. **Start here**: `EXECUTIVE_SUMMARY.md` (understand the why)
2. **Then read**: `ARCHITECTURE_PLAN.md` (understand the what)
3. **Then read**: `COMPONENT_DESIGN.md` (understand the how)
4. **Then read**: `IMPLEMENTATION_ROADMAP.md` (understand the plan)
5. **Then read**: This file - `QUICK_REFERENCE.md` (understand the commands)
6. **Then explore**: Each layer's `README.md` in order:
   - `common/README.md`
   - `infrastructure/README.md`
   - `data-ingestion/README.md`
   - ...and so on

**Total reading time**: ~2 hours  
**Total understanding time**: 1 day (with hands-on exploration)

---

## 🎯 Daily Operations Checklist

### Morning Startup
```bash
# Start the entire pipeline
./pipeline-manager.sh start-all

# Verify everything is healthy
./pipeline-manager.sh health all

# Check for any alerts
./observability/dashboards.sh check-alerts
```

### During Development
```bash
# Working on ML layer
./pipeline-manager.sh stop ml-layer        # Stop what you're working on
# Make changes...
./pipeline-manager.sh rebuild ml-layer     # Rebuild with changes
./pipeline-manager.sh logs ml-layer        # Follow logs
```

### Before Leaving
```bash
# Check status
./pipeline-manager.sh status

# Optional: Stop non-essential layers
./pipeline-manager.sh stop observability
./pipeline-manager.sh stop orchestration-layer

# Keep core running (infra + data pipeline)
# Leave infrastructure, data-ingestion, processing-layer running
```

---

## 🚨 Emergency Procedures

### Complete System Restart
```bash
./pipeline-manager.sh stop-all
./pipeline-manager.sh start-all
```

### Nuclear Option (⚠️ DATA LOSS)
```bash
./pipeline-manager.sh clean
# This will:
# - Stop all containers
# - Remove all volumes
# - Remove all images
# - Clean up networks
```

### Recover from Failed State
```bash
# 1. Check what's running
docker ps -a

# 2. Force remove problematic containers
docker rm -f <container-name>

# 3. Rebuild from infrastructure
./pipeline-manager.sh rebuild infrastructure
./pipeline-manager.sh start-all
```

---

**Keep this guide handy during implementation!** 📌
