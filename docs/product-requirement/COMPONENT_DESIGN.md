# Component Interaction & Data Flow Design

## 🔄 Orchestration Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         pipeline-manager.sh                              │
│                    (Main Orchestrator - Entry Point)                     │
│                                                                           │
│  Commands:                                                                │
│  • start <layer>     → Start layer + auto-resolve dependencies           │
│  • stop <layer>      → Cascade stop (layer → level 0)                    │
│  • rebuild <layer>   → Stop → Build → Start with force recreate          │
│  • status            → Show all layers status                            │
│  • health <layer>    → Run health checks                                 │
└───────────────────────┬─────────────────────────────────────────────────┘
                        │
                        │ Sources & orchestrates
                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          common/ (Shared Library)                        │
├─────────────────────────────────────────────────────────────────────────┤
│  config.sh         │ utils.sh           │ validation.sh                  │
│  ─────────────────────────────────────────────────────────────          │
│  • Layer definitions│ • Logging functions│ • Input validation           │
│  • Service mappings│ • Docker operations│ • Dependency checks           │
│  • Dependencies    │ • Wait functions   │ • Health validators           │
│  • Profiles        │ • Status checkers  │ • Error handling              │
└─────────────────────────────────────────────────────────────────────────┘
                        │
                        │ Imported by all layers
                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         LAYER IMPLEMENTATIONS                            │
│                    (Each has standard interface)                         │
└─────────────────────────────────────────────────────────────────────────┘
           │                    │                    │
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ infrastructure/  │  │ data-ingestion/  │  │ processing/      │
│    manage.sh     │  │    manage.sh     │  │    manage.sh     │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ start()          │  │ start()          │  │ start()          │
│ stop()           │  │ stop()           │  │ stop()           │
│ status()         │  │ status()         │  │ status()         │
│ health()         │  │ health()         │  │ health()         │
│ init()           │  │ validate()       │  │ submit_jobs()    │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## 📊 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              DATA PIPELINE                               │
└─────────────────────────────────────────────────────────────────────────┘

[Infrastructure Layer]
        ↓
   MinIO Ready ──────────┐
   Kafka Ready ──────────┤
   PostgreSQL Ready ─────┤
   Redis Ready ──────────┤
                         │
                         ▼
             [Data Ingestion Layer]
                         ↓
            Kafka Producer generates data
                         ↓
            Kafka Topics (patient-vitals, lab-results, etc.)
                         ↓
            Kafka Consumer writes to MinIO
                         ↓
                 Bronze Layer (Raw JSON)
                         │
                         ▼
             [Processing Layer]
                         ↓
            Spark reads Bronze, transforms
                         ↓
                Silver Layer (Clean Parquet)
                         │
                         ▼
               [ML Layer]
                         ↓
            Feature Engineering reads Silver
                         ↓
            Features stored in Redis + MinIO
                         ↓
            MLflow tracks experiments
                         ↓
            Model Registry (MinIO)
                         │
                         ▼
           [Orchestration Layer]
                         ↓
            Airflow schedules all workflows
                         │
                         ▼
            [Observability Layer]
                         ↓
            Prometheus scrapes metrics
            Grafana visualizes
            ELK collects logs
```

## 🎯 Command Execution Flow

### Example: Start ML Layer

```
User Command:
$ ./pipeline-manager.sh start ml-layer

┌─────────────────────────────────────────────────────────────────┐
│ Step 1: Validate Input                                          │
├─────────────────────────────────────────────────────────────────┤
│ • Check if "ml-layer" exists in config                          │
│ • Validate user permissions                                     │
└────────────────────┬────────────────────────────────────────────┘
                     │ ✓ Valid
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: Resolve Dependencies (from config.sh)                   │
├─────────────────────────────────────────────────────────────────┤
│ ml-layer depends on:                                             │
│ • infrastructure                                                 │
│ • data-ingestion                                                 │
│ • processing-layer                                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: Check Dependency Status                                 │
├─────────────────────────────────────────────────────────────────┤
│ infrastructure:  ✗ NOT RUNNING → Auto-start                     │
│ data-ingestion:  ✗ NOT RUNNING → Auto-start after infra         │
│ processing-layer: ✗ NOT RUNNING → Auto-start after ingestion    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Start Dependencies (Recursive)                          │
├─────────────────────────────────────────────────────────────────┤
│ Call: infrastructure/manage.sh start                             │
│   → Start MinIO, Kafka, PostgreSQL, Redis                       │
│   → Run health checks                                            │
│   → Return success                                               │
│                                                                  │
│ Call: data-ingestion/manage.sh start                            │
│   → Check infrastructure is healthy                              │
│   → Start Kafka producers/consumers                              │
│   → Validate Kafka connectivity                                  │
│   → Return success                                               │
│                                                                  │
│ Call: processing-layer/manage.sh start                          │
│   → Check infrastructure + ingestion healthy                     │
│   → Start Spark cluster                                          │
│   → Verify cluster connectivity                                  │
│   → Return success                                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 5: Start Target Layer                                      │
├─────────────────────────────────────────────────────────────────┤
│ Call: ml-layer/manage.sh start                                  │
│   → Verify all dependencies healthy                              │
│   → Start feature-engineering service                            │
│   → Start mlflow-server                                          │
│   → Start ml-training                                            │
│   → Start model-serving                                          │
│   → Run ML layer health checks                                   │
│   → Return success                                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 6: Post-Start Validation                                   │
├─────────────────────────────────────────────────────────────────┤
│ • Verify all services are running                               │
│ • Display service endpoints                                      │
│ • Show next steps to user                                        │
└─────────────────────────────────────────────────────────────────┘

Result:
✓ Infrastructure Layer started
✓ Data Ingestion Layer started
✓ Processing Layer started
✓ ML Layer started

ML Layer Services:
  • feature-engineering: ✓ RUNNING
  • mlflow-server: ✓ RUNNING (http://localhost:5001)
  • ml-training: ✓ RUNNING
  • model-serving: ✓ RUNNING
```

## 🔧 Interface Implementation Pattern

### Standard Layer Template

Every `layer/manage.sh` follows this pattern:

```bash
#!/bin/bash
# Layer: <LAYER_NAME>
# Purpose: <DESCRIPTION>

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"
source "${SCRIPT_DIR}/../common/config.sh"

LAYER_NAME="<layer-name>"

# ============================================
# Layer-Specific Functions
# ============================================

init_layer() {
    # Layer-specific initialization
    # E.g., create buckets, configure services
}

validate_dependencies() {
    # Check if dependencies are healthy
    local deps=$(get_layer_dependencies "$LAYER_NAME")
    for dep in $deps; do
        if ! check_layer_healthy "$dep"; then
            log_error "Dependency $dep is not healthy"
            return 1
        fi
    done
}

health_check() {
    # Layer-specific health checks
    # E.g., check service endpoints, database connectivity
}

# ============================================
# Standard Interface Implementation
# ============================================

start_layer() {
    local force_recreate=${1:-false}
    
    log_section "Starting $LAYER_NAME"
    
    # 1. Validate dependencies
    validate_dependencies || return 1
    
    # 2. Get services and profile
    local services=$(get_layer_services "$LAYER_NAME")
    local profile=$(get_layer_profile "$LAYER_NAME")
    
    # 3. Start services
    docker_compose_up "$services" "$profile" "$force_recreate"
    
    # 4. Wait for services to be ready
    wait_for_services "$services" 90
    
    # 5. Run initialization
    init_layer
    
    # 6. Health check
    health_check
    
    log_success "$LAYER_NAME started successfully"
}

stop_layer() {
    local remove_volumes=${1:-false}
    
    log_section "Stopping $LAYER_NAME"
    
    local services=$(get_layer_services "$LAYER_NAME")
    docker_compose_down "$services" "$remove_volumes"
    
    log_success "$LAYER_NAME stopped"
}

status_layer() {
    log_section "$LAYER_NAME Status"
    
    local services=$(get_layer_services "$LAYER_NAME")
    display_services_status "$services"
}

# ============================================
# Command Router
# ============================================

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

## 🎨 Error Handling Strategy

### Layered Error Propagation

```
┌─────────────────────────────────────────────────────────────────┐
│ pipeline-manager.sh (Top Level)                                 │
├─────────────────────────────────────────────────────────────────┤
│ • Catches all errors from layers                                │
│ • Provides user-friendly error messages                          │
│ • Suggests remediation steps                                     │
│ • Exit code: 1 on any failure                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ layer/manage.sh (Layer Level)                                   │
├─────────────────────────────────────────────────────────────────┤
│ • Validates dependencies before starting                         │
│ • Logs specific service failures                                 │
│ • Returns error codes to orchestrator                            │
│ • Cleans up on failure (optional)                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ common/utils.sh (Utility Level)                                 │
├─────────────────────────────────────────────────────────────────┤
│ • Logs errors with context                                       │
│ • Provides debug information                                     │
│ • Returns boolean success/failure                                │
└─────────────────────────────────────────────────────────────────┘
```

### Example Error Flow

```
User: ./pipeline-manager.sh start ml-layer

Infrastructure check: FAILED
↓
infrastructure/manage.sh: "PostgreSQL failed to start"
↓
pipeline-manager.sh catches error
↓
Displays:
  [ERROR] Failed to start ml-layer
  Reason: Dependency 'infrastructure' failed
  Details: PostgreSQL failed to start (port already in use)
  
  Suggestions:
    1. Check if port 5432 is available
    2. Run: docker ps -a | grep postgres
    3. Try: ./pipeline-manager.sh stop infrastructure
    4. Then retry: ./pipeline-manager.sh start ml-layer
```

---

## 📝 File Size Comparison

### Before Modularization
```
manage_pipeline.sh         1,087 lines  ❌ Too large
```

### After Modularization
```
common/
  utils.sh                   200 lines  ✅
  config.sh                  150 lines  ✅
  validation.sh               80 lines  ✅

infrastructure/
  manage.sh                  180 lines  ✅
  init-minio.sh               60 lines  ✅
  init-postgres.sh            50 lines  ✅
  health-checks.sh            70 lines  ✅

data-ingestion/
  manage.sh                  120 lines  ✅
  kafka-setup.sh              80 lines  ✅

storage/
  manage.sh                  100 lines  ✅
  bucket-ops.sh               90 lines  ✅

processing-layer/
  manage.sh                  150 lines  ✅
  job-submit.sh               80 lines  ✅

ml-layer/
  manage.sh                  180 lines  ✅
  mlflow-setup.sh             70 lines  ✅

orchestration-layer/
  manage.sh                  130 lines  ✅
  dag-deploy.sh               60 lines  ✅

observability/
  manage.sh                  150 lines  ✅
  metrics-setup.sh            70 lines  ✅

pipeline-manager.sh          250 lines  ✅

Total:                     2,170 lines
Average per file:             96 lines  ✅ Well under 300!
```

**Benefits:**
- ✅ No file exceeds 300 lines
- ✅ Clear separation of concerns
- ✅ Each file has single responsibility
- ✅ Easy to navigate and understand
- ✅ Can test each component independently

---

**This design provides a solid foundation for implementation. Ready to start coding?**
