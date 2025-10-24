# Healthcare Clinical Trials Platform

A comprehensive clinical trials data processing system built with **IBM MQ**, **Spring Boot**, and **microservices architecture** for healthcare environments.

## Architecture Overview

This platform processes clinical trial data through a **message-driven architecture**:

```
Clinical Trial Sites → REST API → Spring JMS → IBM MQ → Lab Processor → EMR/Audit
```

**Core Components:**
- **Clinical Data Gateway** (Port 8080): Receives and validates clinical trial data via REST API
- **Lab Results Processor** (Port 8081): Processes lab results, updates EMR systems, and handles audit logging
- **IBM MQ**: Message broker for reliable clinical data transmission
- **Monitoring Stack**: Prometheus, Grafana, ELK for system observability

## Quick Start (Container-Based Development)

### 1. Setup Development Environment
```bash
# Open VS Code with Alpine container (clean machine approach)
# Run terminal enhancement
chmod +x enhance-terminal.sh
./enhance-terminal.sh

# Setup complete development environment
chmod +x alpine-setup.sh
./alpine-setup.sh
```

### 2. Start the Platform
```bash
# Activate development environment
source .pyenv/bin/activate

# Start IBM MQ container
docker compose up -d

# Build and run Clinical Data Gateway
cd applications/clinical-data-gateway
mvn clean package
java -jar target/clinical-data-gateway-1.0.0.jar

# Generate test clinical data (new terminal)
python operations/scripts/demo/clinical_data_generator.py --count 10 --interval 2-5
```

### 3. Verify the Demo
```bash
# Test gateway health
curl http://localhost:8080/api/clinical/health

# View processing statistics
curl http://localhost:8080/api/clinical/stats
```

## Project Structure

```
clinical-trials-service/
├── .devcontainer/              # VS Code container configuration
├── applications/               # Spring Boot microservices
│   ├── clinical-data-gateway/  # REST API & JMS producer
│   └── lab-results-processor/  # JMS consumer & data processor
├── operations/                 # Demo scripts and automation
│   └── scripts/demo/          # Clinical data generator
├── infrastructure/             # IBM MQ Docker configuration  
├── monitoring/                 # Prometheus, Grafana, ELK stack
├── config/                     # Environment configurations
├── docs/                       # API and architecture documentation
├── test-data/                  # Sample clinical data for testing
└── scripts/                    # Build and deployment utilities
```

## Clinical Data Types

The system processes four types of clinical data:

1. **Patient Demographics** (15%): Age, gender, weight, height, study enrollment
2. **Vital Signs** (40%): Blood pressure, heart rate, temperature, oxygen saturation
3. **Lab Results** (30%): Blood glucose, cholesterol, hemoglobin, liver enzymes
4. **Adverse Events** (15%): Side effects, severity, relation to study drug

## Development Workflow

### Container-First Approach
This project uses **containerized development** to avoid installing tools locally:

```bash
# 1. VS Code + Alpine container (clean slate)
# 2. Enhanced terminal (ZSH + autosuggestions)  
# 3. Complete toolchain (Java 17, Maven, Python, Docker)
# 4. Ready for demo in minutes
```

### Build & Test
```bash
# Build all services
./scripts/build-all.sh

# Run integration tests
./scripts/test-complete-flow.sh

# Clean build artifacts
./scripts/clean-all.sh
```

## Technology Stack

**Backend:**
- **Java 17** with Spring Boot 3.2
- **Spring JMS** for message processing
- **IBM MQ** for reliable messaging
- **Maven** for build management

**Data Generation:**
- **Python 3** with realistic clinical data
- **Faker** for generating HIPAA-compliant test data
- **REST client** for API integration

**Infrastructure:**
- **Docker Compose** for local development
- **Alpine Linux** for lightweight containers
- **ZSH** with enhanced terminal experience

## HIPAA Compliance Features

- **Anonymized Patient IDs**: Format `PT12AB34CD` (no real identifiers)
- **Medical Validation**: Realistic ranges for vitals, labs, and adverse events
- **Audit Trails**: Complete message tracking through the pipeline
- **Secure Transmission**: IBM MQ with persistent message delivery
- **Data Retention**: 7-year retention policy for regulatory compliance

## Monitoring & Observability

- **Health Checks**: `/api/clinical/health` endpoint
- **Metrics**: Processing statistics and success rates
- **Logging**: Structured logs for debugging and compliance
- **Message Tracking**: Unique message IDs through entire pipeline

```bash
# Access monitoring dashboards
Grafana:    http://localhost:3000
Prometheus: http://localhost:9090
Kibana:     http://localhost:5601
```

## Interview Demo Flow

This platform demonstrates several key concepts:

1. **Microservices Architecture**: Loosely coupled services with clear boundaries
2. **Message-Driven Design**: Asynchronous processing with IBM MQ
3. **Domain Modeling**: Healthcare entities with proper validation
4. **Container Development**: Complete environment without local installations
5. **Production Readiness**: Monitoring, logging, and error handling

### Demo Script
```bash
# Terminal 1: Start gateway
java -jar applications/clinical-data-gateway/target/clinical-data-gateway-1.0.0.jar

# Terminal 2: Generate data  
python operations/scripts/demo/clinical_data_generator.py --verbose

# Terminal 3: Monitor
curl -s http://localhost:8080/api/clinical/stats | jq
```

## API Documentation

### POST /api/clinical/data
Receives clinical trial data from healthcare sites.

**Example Payload:**
```json
{
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-09-08T14:30:45.123456",
  "study_phase": "Phase II",
  "site_id": "SITE001",
  "vital_signs": {
    "patient_id": "PT12AB34CD",
    "systolic_bp": 128,
    "diastolic_bp": 82,
    "heart_rate": 74,
    "temperature_celsius": 37.1
  }
}
```

## Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

🏥

┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLINICAL MLOPS DATA PIPELINE                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  1. STREAMING INGESTION (Real-time events)                  │
├─────────────────────────────────────────────────────────────┤
│  Kafka Producer → Kafka Topics → Kafka Consumer             │
│  ↓                                                           │
│  MinIO Bronze Layer (raw/topic/date=YYYY-MM-DD/hour=HH/)   │
│  Format: JSON (newline-delimited)                           │
│  Purpose: Immutable raw event capture                       │
│  Retention: 90 days                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. DATA PROCESSING (Clean & validate)                      │
├─────────────────────────────────────────────────────────────┤
│  Spark Jobs (Bronze → Silver transformation)                │
│  ↓                                                           │
│  MinIO Silver Layer (processed/topic/date=YYYY-MM-DD/)     │
│  Format: Parquet (compressed, columnar)                     │
│  Purpose: ML-ready, deduplicated, validated data            │
│  Retention: 2 years                                         │
│                                                              │
│  Transformations:                                            │
│  • Deduplication (patient_id, timestamp, source)            │
│  • Validation (physiological ranges)                        │
│  • Standardization (units, formats)                         │
│  • Enrichment (derived metrics)                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. FEATURE ENGINEERING (Create ML features)                │
├─────────────────────────────────────────────────────────────┤
│  Feature Engineering Pipeline (Spark/Python)                │
│  ↓                                                           │
│  Creates 120+ features:                                     │
│  • Temporal: rolling windows (1h, 6h, 24h)                 │
│  • Derived: pulse pressure, MAP, trends                     │
│  • Aggregations: patient-level statistics                   │
│  • Context: demographics, trial arm                         │
│                                                              │
│  Writes to DUAL STORAGE:                                    │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  OFFLINE FEATURE STORE                       │          │
│  │  (Historical training & batch scoring)       │          │
│  ├──────────────────────────────────────────────┤          │
│  │  Storage: MinIO (S3)                         │          │
│  │  Location: features/offline/date=YYYY-MM-DD/ │          │
│  │  Format: Parquet (partitioned by date)       │          │
│  │  Schema:                                      │          │
│  │    - patient_id                               │          │
│  │    - timestamp                                │          │
│  │    - feature_1...feature_120                  │          │
│  │    - label (adverse_event_24h)                │          │
│  │                                                │          │
│  │  Use Cases:                                   │          │
│  │  ✓ Model training (large batch reads)        │          │
│  │  ✓ Batch predictions (daily scoring)         │          │
│  │  ✓ Feature backfilling                        │          │
│  │  ✓ Historical analysis                        │          │
│  │  ✓ DVC versioning                             │          │
│  │                                                │          │
│  │  Access Pattern: Scan by date range           │          │
│  │  Retention: 2 years                           │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  ONLINE FEATURE STORE                        │          │
│  │  (Real-time predictions < 200ms)             │          │
│  ├──────────────────────────────────────────────┤          │
│  │  Storage: Redis (in-memory key-value)        │          │
│  │  Key Pattern: patient:{patient_id}:features  │          │
│  │  Value: JSON/Hash with latest features       │          │
│  │  TTL: 48 hours (rolling window)              │          │
│  │                                                │          │
│  │  Example Entry:                               │          │
│  │  Key: "patient:PT00042:features"             │          │
│  │  Value: {                                     │          │
│  │    "updated_at": "2025-10-07T16:30:00Z",     │          │
│  │    "heart_rate_mean_1h": 78.5,               │          │
│  │    "heart_rate_std_24h": 12.3,               │          │
│  │    "bp_systolic_trend_6h": 2.1,              │          │
│  │    ...120 features...                         │          │
│  │  }                                             │          │
│  │                                                │          │
│  │  Use Cases:                                   │          │
│  │  ✓ Real-time predictions (API serving)       │          │
│  │  ✓ Fast feature lookup (< 10ms)              │          │
│  │  ✓ Incremental updates                        │          │
│  │                                                │          │
│  │  Access Pattern: Point lookup by patient_id   │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  Sync Strategy:                                             │
│  • Batch job (hourly): Silver → Offline → Online           │
│  • Stream processing: Real-time updates to Online           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. MODEL TRAINING (PyTorch)                                │
├─────────────────────────────────────────────────────────────┤
│  Training Pipeline reads from OFFLINE FEATURE STORE         │
│  ↓                                                           │
│  Load Parquet files from MinIO (last 90 days)              │
│  • Train/Val/Test split (70/15/15)                         │
│  • PyTorch DataLoader                                       │
│  • Track with MLflow                                        │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  ML METADATA STORE                            │          │
│  │  (Experiment tracking & model registry)      │          │
│  ├──────────────────────────────────────────────┤          │
│  │  Storage: PostgreSQL (mlflow)                │          │
│  │  Tables:                                      │          │
│  │    - experiments                              │          │
│  │    - runs                                     │          │
│  │    - params (learning_rate, epochs, ...)     │          │
│  │    - metrics (train_loss, val_auroc, ...)    │          │
│  │    - tags (git_commit, data_version, ...)    │          │
│  │    - registered_models                        │          │
│  │    - model_versions (staging, production)    │          │
│  │                                                │          │
│  │  Artifacts stored in MinIO:                   │          │
│  │    - Model weights (.pth)                     │          │
│  │    - Preprocessing (scaler.pkl)               │          │
│  │    - Confusion matrices                       │          │
│  │    - Feature importance plots                 │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  5. MODEL SERVING (FastAPI)                                 │
├─────────────────────────────────────────────────────────────┤
│  API Endpoint: POST /predict                                │
│  Request: {"patient_id": "PT00042"}                        │
│  ↓                                                           │
│  Step 1: Fetch features from ONLINE FEATURE STORE (Redis)  │
│    redis.get("patient:PT00042:features")                   │
│    Latency: < 10ms                                          │
│  ↓                                                           │
│  Step 2: Load model from MLflow Registry                    │
│    model = mlflow.pytorch.load_model("production")         │
│  ↓                                                           │
│  Step 3: Run inference                                      │
│    prediction = model.predict(features)                     │
│  ↓                                                           │
│  Step 4: Log prediction to PostgreSQL                       │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  PREDICTION LOGS (Audit & monitoring)        │          │
│  │  Storage: PostgreSQL (predictions)           │          │
│  ├──────────────────────────────────────────────┤          │
│  │  Table: predictions                           │          │
│  │    - id (UUID)                                │          │
│  │    - patient_id                               │          │
│  │    - timestamp                                │          │
│  │    - prediction_score (0.0-1.0)              │          │
│  │    - risk_level (LOW/MEDIUM/HIGH)            │          │
│  │    - model_version                            │          │
│  │    - latency_ms                               │          │
│  │    - features_used (JSONB)                    │          │
│  │                                                │          │
│  │  Indexes:                                     │          │
│  │    - (patient_id, timestamp)                  │          │
│  │    - (timestamp) for drift monitoring         │          │
│  │                                                │          │
│  │  Use Cases:                                   │          │
│  │  ✓ Audit trail (regulatory compliance)       │          │
│  │  ✓ Drift detection (compare predictions)     │          │
│  │  ✓ Performance monitoring                     │          │
│  │  ✓ Ground truth labeling (when event occurs) │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  Response: {                                                │
│    "patient_id": "PT00042",                                │
│    "adverse_event_probability": 0.73,                      │
│    "risk_level": "HIGH",                                   │
│    "model_version": "v2.3.1"                               │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  6. MONITORING & DRIFT DETECTION                            │
├─────────────────────────────────────────────────────────────┤
│  Monitoring Service (Python)                                │
│  ↓                                                           │
│  Queries PostgreSQL predictions table:                      │
│  • Calculate rolling 7-day AUROC                           │
│  • Compare prediction distribution vs training             │
│  • Detect feature drift (KS test)                          │
│  • Alert on performance degradation                         │
│  ↓                                                           │
│  Metrics sent to Prometheus → Grafana dashboards           │
│                                                              │
│  If AUROC < 0.80 → Trigger retraining                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  7. ORCHESTRATION (Airflow)                                 │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────┐          │
│  │  WORKFLOW METADATA STORE                      │          │
│  │  Storage: PostgreSQL (airflow)               │          │
│  ├──────────────────────────────────────────────┤          │
│  │  Tables:                                      │          │
│  │    - dag                                      │          │
│  │    - dag_run                                  │          │
│  │    - task_instance                            │          │
│  │    - xcom (inter-task data passing)           │          │
│  │                                                │          │
│  │  DAGs:                                        │          │
│  │  • data_processing_dag (hourly)               │          │
│  │    - Spark: Bronze → Silver                   │          │
│  │                                                │          │
│  │  • feature_engineering_dag (hourly)           │          │
│  │    - Read Silver Parquet                      │          │
│  │    - Compute features                         │          │
│  │    - Write to Offline (MinIO)                 │          │
│  │    - Update Online (Redis)                    │          │
│  │                                                │          │
│  │  • model_monitoring_dag (6-hourly)            │          │
│  │    - Check AUROC                              │          │
│  │    - Detect drift                             │          │
│  │    - Alert if needed                          │          │
│  │                                                │          │
│  │  • model_retraining_dag (triggered)           │          │
│  │    - Load from Offline Feature Store          │          │
│  │    - Train new model                          │          │
│  │    - Evaluate & promote                       │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘


📊 What It Does
The script checks all 6 levels of your pipeline:
Level 0: Infrastructure

✅ MinIO server accessible
✅ MinIO bucket exists
✅ Kafka broker accessible
✅ Redis server accessible
✅ MLflow server accessible
✅ PostgreSQL databases accessible

Level 1: Data Ingestion

✅ Kafka producer running
✅ Kafka consumer running
✅ Kafka topics exist
✅ Bronze data exists

Level 2: Data Processing

✅ Spark master/worker running
✅ Spark accessible
✅ Silver data exists

Level 3: Feature Engineering

✅ Feature engineering service running
✅ Offline features exist (MinIO)
✅ Online features exist (Redis)

Level 4: ML Pipeline

✅ Model serving API running
✅ Health endpoint accessible

Level 5: Observability

✅ Prometheus running
✅ Grafana running
✅ Services accessible

Data Flow Validation

📊 Counts files in Bronze layer
📊 Counts files in Silver layer
📊 Counts files in Feature store

```sh
# Use MinIO client to browse entire bucket
docker exec -it minio sh -c "mc alias set local http://localhost:9000 minioadmin minioadmin && mc ls --recursive local/clinical-mlops/"
```