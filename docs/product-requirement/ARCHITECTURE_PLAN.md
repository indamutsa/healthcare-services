# 🏗️ Clinical MLOps Pipeline - Modularization Plan

## 📋 Table of Contents
1. [Current State Analysis](#current-state-analysis)
2. [Target Architecture](#target-architecture)
3. [Folder Structure Design](#folder-structure-design)
4. [Layer Responsibilities](#layer-responsibilities)
5. [Service-to-Layer Mapping](#service-to-layer-mapping)
6. [Interface Contracts](#interface-contracts)
7. [Dependency Graph](#dependency-graph)
8. [Migration Strategy](#migration-strategy)

---

## 1. Current State Analysis

### Problems Identified
- **1087 lines** in a single bash script
- **Mixed concerns**: Infrastructure, data flow, ML, orchestration all intertwined
- **Hard to maintain**: Changes require understanding the entire script
- **No clear boundaries**: Functions are tightly coupled
- **Difficult testing**: Cannot test individual components in isolation
- **Poor reusability**: Cannot reuse layer logic elsewhere

### Current Level Structure
```
Level 0: Infrastructure (Base services)
Level 1: Data Ingestion (Kafka producers/consumers)
Level 2: Data Processing (Spark cluster)
Level 3: Feature Engineering
Level 4: ML Pipeline (MLflow, training, serving)
Level 5: Observability (Airflow, Prometheus, etc.)
```

---

## 2. Target Architecture

### Design Principles

**Think of this like a microservices architecture:**
- Each layer = A bounded context (DDD concept)
- Clear separation of concerns
- Single responsibility per layer
- Well-defined interfaces between layers
- Independent deployability and testability

**Analogy for you:**
Imagine each layer as a separate microservice with its own API. The orchestrator is like an API gateway that knows how to call each service's endpoints in the right order.

### Layer-Based Architecture

```
scripts/
├── common/                    # Shared utilities (like a shared library)
│   ├── utils.sh              # Common functions (logging, Docker ops)
│   ├── config.sh             # Central configuration (service definitions)
│   └── validation.sh         # Input validation functions
│
├── infrastructure/           # Layer 0: Foundation services
│   ├── manage.sh            # Infrastructure orchestration
│   ├── init-minio.sh        # MinIO bucket setup
│   ├── init-postgres.sh     # Database initialization
│   └── health-checks.sh     # Infra health validation
│
├── data-ingestion/          # Layer 1: Data collection
│   ├── manage.sh            # Ingestion orchestration
│   ├── kafka-setup.sh       # Topic creation, producer setup
│   └── validators.sh        # Data validation rules
│
├── storage/                 # MinIO management utilities
│   ├── manage.sh            # Storage operations
│   ├── bucket-ops.sh        # Bucket operations (CRUD)
│   └── data-sync.sh         # Bronze/Silver/Gold sync utilities
│
├── processing-layer/        # Layer 2: Spark processing
│   ├── manage.sh            # Spark cluster orchestration
│   ├── job-submit.sh        # Spark job submission
│   └── monitoring.sh        # Spark metrics collection
│
├── ml-layer/                # Layer 3+4: Feature Engineering + ML
│   ├── manage.sh            # ML pipeline orchestration
│   ├── feature-setup.sh     # Feature store initialization
│   ├── mlflow-setup.sh      # MLflow configuration
│   └── model-ops.sh         # Model deployment utilities
│
├── orchestration-layer/     # Layer 5a: Airflow DAGs
│   ├── manage.sh            # Airflow orchestration
│   ├── dag-deploy.sh        # DAG deployment
│   └── scheduler-ops.sh     # Scheduler management
│
├── observability/           # Layer 5b: Monitoring
│   ├── manage.sh            # Monitoring orchestration
│   ├── metrics-setup.sh     # Prometheus config
│   ├── dashboards.sh        # Grafana dashboard import
│   └── alerts.sh            # Alert configuration
│
└── pipeline-manager.sh      # 🎯 MAIN ORCHESTRATOR (replaces manage_pipeline.sh)
```

---

## 3. Folder Structure Design

### Common Layer (Shared Library)

**Purpose**: Reusable functions that ALL layers need

```bash
common/
├── utils.sh              # Logging, Docker ops, wait functions
├── config.sh             # Layer definitions, service mappings
├── validation.sh         # Input validation, level checks
└── README.md             # Documentation for common utilities
```

**Key Functions**:
- `log_info()`, `log_error()`, `log_success()`
- `check_service_running()`, `wait_for_service()`
- `docker_compose_up()`, `docker_compose_down()`
- `validate_layer()`, `get_layer_dependencies()`

### Infrastructure Layer

**Purpose**: Manage foundational services (databases, message queues, object storage)

```bash
infrastructure/
├── manage.sh             # Main entry point (start, stop, status)
├── init-minio.sh         # Create buckets, set policies
├── init-postgres.sh      # Initialize MLflow/Airflow DBs
├── init-kafka.sh         # Create topics, configure brokers
├── health-checks.sh      # Verify all infra services
└── README.md
```

**Services Managed**: minio, postgres-mlflow, postgres-airflow, redis, kafka, zookeeper

### Data Ingestion Layer

**Purpose**: Manage data producers and consumers

```bash
data-ingestion/
├── manage.sh             # Main entry point
├── kafka-setup.sh        # Configure producers/consumers
├── producer-ops.sh       # Start/stop producers
├── consumer-ops.sh       # Start/stop consumers
└── README.md
```

**Services Managed**: kafka-producer, kafka-consumer, clinical-mq, clinical-data-gateway

### Storage Layer

**Purpose**: MinIO data lake management utilities

```bash
storage/
├── manage.sh             # Main entry point
├── bucket-ops.sh         # CRUD operations on buckets
├── data-lifecycle.sh     # Bronze → Silver → Gold transitions
├── backup-restore.sh     # Data backup utilities
└── README.md
```

**Note**: No dedicated services, but provides utilities for data lake operations

### Processing Layer

**Purpose**: Spark cluster and job management

```bash
processing-layer/
├── manage.sh             # Main entry point
├── cluster-ops.sh        # Start/stop Spark cluster
├── job-submit.sh         # Submit Spark jobs
├── job-monitor.sh        # Monitor job status
└── README.md
```

**Services Managed**: spark-master, spark-worker, spark-streaming, spark-batch

### ML Layer

**Purpose**: Machine learning pipeline (feature engineering + model training/serving)

```bash
ml-layer/
├── manage.sh             # Main entry point
├── feature-setup.sh      # Feature store initialization
├── mlflow-setup.sh       # MLflow server + experiments
├── training-ops.sh       # Model training utilities
├── serving-ops.sh        # Model serving utilities
└── README.md
```

**Services Managed**: feature-engineering, mlflow-server, ml-training, model-serving

### Orchestration Layer

**Purpose**: Airflow workflow orchestration

```bash
orchestration-layer/
├── manage.sh             # Main entry point
├── airflow-init.sh       # Initialize Airflow (create admin user, etc.)
├── dag-deploy.sh         # Deploy/update DAGs
├── connection-setup.sh   # Configure Airflow connections
└── README.md
```

**Services Managed**: airflow-init, airflow-webserver, airflow-scheduler

### Observability Layer

**Purpose**: Monitoring, logging, and alerting

```bash
observability/
├── manage.sh             # Main entry point
├── prometheus-setup.sh   # Configure Prometheus targets
├── grafana-setup.sh      # Import dashboards, configure datasources
├── elk-setup.sh          # Configure ELK stack
├── alerts-setup.sh       # Configure alert rules
└── README.md
```

**Services Managed**: prometheus, grafana, opensearch, opensearch-dashboards, filebeat

---

## 4. Layer Responsibilities

### Clear Separation of Concerns

| Layer | Primary Responsibility | What It Does | What It Doesn't Do |
|-------|----------------------|--------------|-------------------|
| **Common** | Shared utilities | Logging, Docker ops, validation | No business logic, no service management |
| **Infrastructure** | Foundation services | Start/stop core services, init DBs | No data processing, no ML logic |
| **Data Ingestion** | Data collection | Manage producers/consumers | No data transformation |
| **Storage** | Data lake operations | Bucket management, data lifecycle | No data processing |
| **Processing** | Data transformation | Spark jobs, Bronze→Silver | No ML training |
| **ML Layer** | Model lifecycle | Training, serving, feature engineering | No data ingestion |
| **Orchestration** | Workflow scheduling | DAG management, pipeline orchestration | No direct service management |
| **Observability** | System monitoring | Metrics, logs, alerts | No application logic |

---

## 5. Service-to-Layer Mapping

### Complete Service Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│ INFRASTRUCTURE LAYER (Level 0)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • minio              → Object storage (S3-compatible)           │
│ • minio-setup        → MinIO initialization container           │
│ • postgres-mlflow    → MLflow backend store                     │
│ • postgres-airflow   → Airflow metadata DB                      │
│ • redis              → Feature store (online serving)           │
│ • redis-insight      → Redis GUI                                │
│ • zookeeper          → Kafka coordination                       │
│ • kafka              → Message broker                           │
│ • kafka-ui           → Kafka management UI                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ DATA INGESTION LAYER (Level 1)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • kafka-producer             → Generate synthetic data          │
│ • kafka-consumer             → Consume to MinIO (Bronze)        │
│ • clinical-mq                → Clinical message queue           │
│ • clinical-data-gateway      → Data ingestion gateway           │
│ • lab-results-processor      → Lab results processing           │
│ • clinical-data-generator    → Synthetic clinical data          │
│                                                                  │
│ Dependencies: infrastructure                                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STORAGE LAYER (Utilities Only)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • No dedicated services                                          │
│ • Provides scripts for MinIO operations                         │
│ • Data lifecycle management (Bronze/Silver/Gold)                │
│                                                                  │
│ Dependencies: infrastructure                                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PROCESSING LAYER (Level 2)                                      │
├─────────────────────────────────────────────────────────────────┤
│ • spark-master       → Spark master node                        │
│ • spark-worker       → Spark worker node(s)                     │
│ • spark-streaming    → Real-time processing                     │
│ • spark-batch        → Batch processing jobs                    │
│                                                                  │
│ Dependencies: infrastructure, data-ingestion                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ML LAYER (Level 3 + 4 Combined)                                 │
├─────────────────────────────────────────────────────────────────┤
│ • feature-engineering → Feature transformation & storage        │
│ • mlflow-server       → Experiment tracking & model registry    │
│ • ml-training         → Model training jobs                     │
│ • model-serving       → Model inference API                     │
│                                                                  │
│ Dependencies: infrastructure, data-ingestion, processing-layer   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ORCHESTRATION LAYER (Level 5a)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • airflow-init       → Initialize Airflow                       │
│ • airflow-webserver  → Airflow UI                               │
│ • airflow-scheduler  → DAG scheduler                            │
│                                                                  │
│ Dependencies: infrastructure, data-ingestion, processing, ml     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ OBSERVABILITY LAYER (Level 5b)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • prometheus         → Metrics collection                       │
│ • grafana            → Metrics visualization                    │
│ • monitoring-service → Custom monitoring service                │
│ • opensearch         → Log storage & search                     │
│ • opensearch-dashboards → Log visualization                     │
│ • data-prepper       → Log processing                           │
│ • filebeat           → Log shipping                             │
│                                                                  │
│ Dependencies: ALL previous layers                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Interface Contracts

### Standard Interface for Each Layer

Every `manage.sh` script in each layer MUST implement these commands:

```bash
# Standard operations
./manage.sh start              # Start layer services
./manage.sh start-force        # Force recreate containers
./manage.sh stop               # Stop layer (keep volumes)
./manage.sh stop-full          # Stop layer (remove volumes)
./manage.sh restart            # Restart layer
./manage.sh status             # Show layer status
./manage.sh health             # Run health checks

# Build operations
./manage.sh build              # Build images
./manage.sh rebuild            # Force rebuild images

# Layer-specific operations (optional)
./manage.sh init               # Initialize layer (create configs, etc.)
./manage.sh validate           # Validate layer configuration
./manage.sh logs               # Follow logs for layer services
```

### Communication Protocol

**Layers communicate through:**
1. **Docker Compose profiles** - Defined in config.sh
2. **Dependency declaration** - Each layer declares what it needs
3. **Health checks** - Each layer validates its dependencies
4. **Return codes** - Standard exit codes (0=success, 1=error)

### Example Interface Contract

```bash
# infrastructure/manage.sh MUST provide:
start()        # Start all infrastructure services
stop()         # Stop all infrastructure services
status()       # Return running status
health()       # Validate all services are healthy
init()         # Initialize databases, buckets, topics

# data-ingestion/manage.sh MUST provide:
start()        # Start ingestion services
stop()         # Stop ingestion services
status()       # Return running status
validate()     # Validate Kafka connectivity, etc.
```

---

## 7. Dependency Graph

### Layer Dependency Flow

```
┌─────────────────────┐
│   Infrastructure    │ ← Level 0 (No dependencies)
│   (Foundation)      │
└──────────┬──────────┘
           │
           ├────────────────────┐
           │                    │
           ▼                    ▼
┌──────────────────┐   ┌────────────────┐
│  Data Ingestion  │   │    Storage     │
│   (Producers)    │   │   (Utilities)  │
└────────┬─────────┘   └────────────────┘
         │
         ▼
┌──────────────────┐
│  Processing      │
│  (Spark)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  ML Layer        │
│  (Training)      │
└────────┬─────────┘
         │
         ├────────────────────┐
         │                    │
         ▼                    ▼
┌─────────────────┐   ┌──────────────────┐
│ Orchestration   │   │  Observability   │
│  (Airflow)      │   │  (Monitoring)    │
└─────────────────┘   └──────────────────┘
```

### Dependency Matrix

| Layer | Depends On |
|-------|-----------|
| infrastructure | (none) |
| data-ingestion | infrastructure |
| storage | infrastructure |
| processing-layer | infrastructure, data-ingestion |
| ml-layer | infrastructure, data-ingestion, processing-layer |
| orchestration-layer | infrastructure, data-ingestion, processing-layer, ml-layer |
| observability | ALL layers |

---

## 8. Migration Strategy

### Phase 1: Extract Common Utilities (Week 1)
- Create `common/utils.sh` with logging, Docker ops
- Create `common/config.sh` with layer definitions
- Create `common/validation.sh` with input validation
- Test common functions in isolation

### Phase 2: Modularize Infrastructure (Week 1-2)
- Extract infrastructure functions to `infrastructure/manage.sh`
- Create MinIO initialization script
- Create Postgres initialization script
- Test infrastructure layer independently

### Phase 3: Modularize Data Pipeline (Week 2)
- Create `data-ingestion/manage.sh`
- Create `processing-layer/manage.sh`
- Test data flow: Ingestion → Processing

### Phase 4: Modularize ML Pipeline (Week 3)
- Create `ml-layer/manage.sh`
- Extract MLflow setup
- Extract feature engineering logic

### Phase 5: Modularize Observability (Week 3)
- Create `orchestration-layer/manage.sh`
- Create `observability/manage.sh`
- Configure monitoring and alerts

### Phase 6: Create Main Orchestrator (Week 4)
- Create `pipeline-manager.sh` (new main entry point)
- Implement cascade logic
- Implement dependency resolution
- Test end-to-end workflows

### Phase 7: Testing & Documentation (Week 4)
- Write integration tests
- Document each layer
- Create usage examples
- Migration guide for users

---

## 9. Success Criteria

### Quantitative Goals
- ✅ No file over 300 lines (current: 1087 lines)
- ✅ Each layer independently testable
- ✅ 90% code reusability through common utilities
- ✅ Clear separation of concerns (0 cross-layer dependencies)

### Qualitative Goals
- ✅ Easy to understand (new dev can understand one layer at a time)
- ✅ Easy to maintain (change in one layer doesn't break others)
- ✅ Easy to extend (add new layer without modifying existing ones)
- ✅ Easy to test (can test layers in isolation)

---

## 10. Next Steps

### Immediate Actions
1. Review and approve this architecture plan
2. Create folder structure
3. Start with Phase 1 (Common utilities)
4. Implement layers incrementally
5. Test each layer before moving to next

### Questions to Answer
- [ ] Do we need any additional layers?
- [ ] Should storage be a separate layer or part of infrastructure?
- [ ] How do we handle configuration files (env vars, secrets)?
- [ ] Do we need a separate testing layer?
- [ ] Should we add a deployment/CI-CD layer?

---

**Ready to proceed?** Once you approve this plan, we'll start implementing phase by phase.
