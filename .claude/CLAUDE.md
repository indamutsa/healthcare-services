# Clinical Trials MLOps Platform - Project Guide

!IMPORTANT: ALWAYS, START BY PLANNING TODO, CHECK THEM OUT AS YOU COMPLETE

**Version**: 2.0 | **Updated**: January 2025
**Status**: Levels 0-5 Production | Level 6 In Progress | Levels 7-8 Planned

---

## Vision & Architecture

### Primary Vision
Production-grade, HIPAA-aligned MLOps platform managing clinical trial data lifecycle from ingestion through real-time ML predictions using modular, level-based architecture.

### Core Principles
- **Layered Hierarchy**: 8 progressive levels, each depending only on lower levels
- **Immutable Data**: Bronze → Silver → Gold with full lineage tracking
- **Dual-Store Pattern**: MinIO (offline training) + Redis (online serving)
- **Service Mesh Ready**: Health checks, structured logging, metrics endpoints
- **Domain-Driven**: Clear bounded contexts (Ingestion, Processing, Features, ML, Orchestration)

---

## Implementation Status

| Level | Name | Key Services | Status |
|-------|------|--------------|--------|
| **0** | Infrastructure | MinIO, PostgreSQL, Redis, Kafka, Zookeeper | ✅ Production |
| **1** | Data Ingestion | Kafka, IBM MQ bridge, Clinical Gateway, Lab Processor | ✅ Production |
| **2** | Data Processing | Spark (master/workers), streaming/batch jobs | ✅ Production |
| **3** | Feature Engineering | Feature service, offline/online stores, sync utilities | ✅ Production |
| **4** | ML Pipeline | MLflow, training jobs, serving API, Redis cache | ✅ Production |
| **5** | Orchestration | Airflow (scheduler, webserver, workers) | ✅ Production |
| **6** | Observability | Prometheus, Grafana, OpenSearch, Filebeat | 🚧 In Progress |
| **7** | Platform | ArgoCD, K8s, Istio/Linkerd, Argo Rollouts | 📋 Planned |
| **8** | Security | Metasploit, Burp Suite, OWASP ZAP, Trivy | 📋 Planned |

---

## Level Details

### Level 0: Infrastructure
**Storage, messaging, caching foundation**

**Services**: MinIO (S3-compatible storage), PostgreSQL (metadata), Redis (cache + online features), Kafka + Zookeeper (streaming), Kafka UI, Redis Insight

**Storage Architecture**:
- MinIO: `bronze/`, `silver/`, `gold/`, `features/`, `mlflow/`
- PostgreSQL: `mlflow_db`, `airflow_db`
- Redis: `features:*`, `predictions:*`, `sessions:*`

### Level 1: Data Ingestion
**Capture clinical data from multiple sources**

**Services**: Clinical Data Gateway (FastAPI REST API), Lab Results Processor, Kafka producers/consumers, IBM MQ bridge

**Capabilities**: JSON validation, topic routing, Bronze persistence (immutable parquet), dead letter queues, correlation IDs

**API Endpoints** (localhost:8001):
- `POST /api/v1/clinical-data` - Submit clinical data
- `POST /api/v1/lab-results` - Submit lab results
- `GET /health`, `GET /metrics`

**Kafka Topics**: `clinical-events`, `lab-results`, `adverse-events`, `dlq-clinical`, `dlq-lab`

### Level 2: Data Processing
**Transform Bronze → Silver → Gold**

**Services**: Spark Master, Spark Workers (scalable), streaming jobs, batch jobs

**Capabilities**: Real-time Kafka streaming, batch ETL, data quality validation, deduplication, date partitioning, schema evolution

**Processing**: Bronze (raw) → Silver (cleaned, validated, standardized) → Gold (aggregated, analytics-ready)

**Spark UI**: http://localhost:8080

### Level 3: Feature Engineering
**Generate 120+ features for ML**

**Services**: Feature Engineering Service, Offline Store (MinIO parquet), Online Store (Redis), comparison/sync utilities

**Feature Categories**:
- Temporal (60+): rolling windows, lag features, trends
- Clinical (40+): vitals, labs, medications, adverse events
- Contextual (20+): sites, demographics, compliance

**Dual-Store**:
- **Offline**: Historical features (parquet, point-in-time correct) for training
- **Online**: Real-time features (Redis hashes, <5ms latency) for serving

**Commands**:
```bash
./pipeline-manager.sh --compare-stores [DATE] --level 3
./pipeline-manager.sh --query-offline-features [DATE] --level 3
./pipeline-manager.sh --query-online-features [PATIENT_ID] --level 3
```

### Level 4: ML Pipeline
**Train, register, serve models**

**Services**: MLflow (tracking + registry), training jobs, serving API (FastAPI), Redis prediction cache

**Capabilities**: Experiment tracking, model versioning, automated training, REST predictions, response caching (5min TTL), warmup on startup

**Serving API** (localhost:8000):
- `POST /v1/predict` - Model inference
- `GET /health`, `GET /ready`, `GET /metrics`, `GET /models`

**Training Pipeline**: Feature retrieval → validation → train/val/test split → training (XGBoost, LightGBM) → hyperparameter tuning (Optuna) → MLflow logging → registration → promotion

**Caching**: `prediction:{model}:{version}:{patient}:{feature_hash}`, 5min TTL, 70%+ hit rate

### Level 5: Orchestration (In Progress)
**Automate workflows**

**Services**: Airflow (scheduler, webserver, workers, DAG processors)

**Planned DAGs**:
1. **Daily Batch Processing** (2 AM): Bronze → Silver → Gold transformations
2. **Feature Sync** (every 15min): Offline → online store sync
3. **Model Retraining** (weekly): Drift detection → training → promotion
4. **Data Quality** (hourly): Freshness, schema, anomaly checks

**Access**: http://localhost:8081 (admin/admin)

**Status**: Infrastructure ✅ | DAGs 🚧 | Testing 🚧 | Alerting ⏳

---

## Data Flow

```
Clinical Sites → REST API → [IBM MQ, Kafka] → Consumers → MinIO Bronze
    → Spark Processing → MinIO Silver → Feature Engineering
    → [Offline Store (MinIO), Online Store (Redis)]
    → ML Training (MLflow) → Model Registry → Serving API → Predictions
```

**Data Layers**:
- **Bronze**: Raw parquet, immutable, indefinite retention, audit trail
- **Silver**: Cleaned parquet, standardized, 90-day retention, analytics-ready
- **Gold**: Aggregated parquet, business metrics, 30-day retention, reporting
- **Features**: Parquet (offline) + Redis (online), 30-day retention, ML training/serving

---

## Tech Stack

**Languages**: Python 3.11+, TypeScript/Node.js, Java, Bash
**Backend**: FastAPI, NestJS, SpringBoot
**Infrastructure**: Docker 24+, Docker Compose v2, Kubernetes 1.28+ (planned)
**Databases**: PostgreSQL 15, Redis 7, MinIO
**Processing**: Spark 3.5, Kafka 3.6, Parquet
**ML**: XGBoost, LightGBM, scikit-learn, PyTorch (future)
**MLOps**: MLflow, Optuna, Great Expectations
**Orchestration**: Airflow 2.8, Celery
**Observability** (planned): Prometheus, Grafana, OpenSearch, Jaeger
**Platform** (planned): ArgoCD, Istio/Linkerd, Argo Rollouts
**Security** (planned): Metasploit, Burp Suite, OWASP ZAP, Trivy, SonarQube
**Testing**: pytest, Jest, React Testing Library

---

## Getting Started

### Prerequisites
- OS: Linux (Ubuntu 22.04+), macOS 13+, Windows WSL2
- Docker 24+, Docker Compose v2
- Python 3.11+
- RAM: 16GB min (32GB recommended)
- Storage: 50GB
- CPU: 4+ cores

### Quick Start
```bash
# Make scripts executable
chmod +x pipeline-manager.sh enhance-terminal.sh alpine-setup.sh

# Start infrastructure only
./pipeline-manager.sh --start --level 0

# Start full ML pipeline (Levels 0-4)
./pipeline-manager.sh --start --level 4

# Health check
./pipeline-manager.sh --health-check --level 4

# View all info
./pipeline-manager.sh -vhso --level 4
```

### Admin Consoles
- MinIO: http://localhost:9001 (minioadmin/minioadmin)
- Kafka UI: http://localhost:8090
- Redis Insight: http://localhost:5540
- Spark: http://localhost:8080
- MLflow: http://localhost:5000
- Airflow: http://localhost:8081 (admin/admin)

---

## Pipeline Manager Guide

### Command Structure
```bash
./pipeline-manager.sh [COMMAND] [FLAGS] --level <0-5|all>
```

### Management Commands (Mutually Exclusive)
- `--start` - Start level + dependencies
- `--stop` - Stop level (⚠️ removes volumes)
- `--restart-rebuild` - Rebuild images and restart
- `--clean` - Full cleanup (services, volumes, images)

### Information Flags (Composable)
- `-v, --visualize` - Show architecture diagrams
- `-h, --health-check` - Run health probes
- `-l, --logs` - Tail service logs
- `-o, --open` - Display service URLs
- `-s, --summary` - Show container status
- `-d, --demo-data` - Sample payloads

**Examples**:
```bash
# Combined flags
./pipeline-manager.sh -vhso --level 4

# Rebuild specific level
./pipeline-manager.sh --restart-rebuild --level 3

# Clean everything
./pipeline-manager.sh --clean --level all
```

### Level 3 Feature Store Utilities
```bash
--compare-stores [DATE]           # Compare offline vs online
--query-offline-features [DATE]   # Query parquet features
--query-online-features [ID]      # Query Redis features
--monitor-feature-pipeline [DATE] # End-to-end health check
--inspect-feature-volume [NAME]   # Inspect Docker volumes
```

---

## Testing & Validation

### Quick Validation
```bash
# Health checks
./pipeline-manager.sh --health-check --level 4

# Test ingestion
curl -X POST http://localhost:8001/api/v1/clinical-data \
  -H "Content-Type: application/json" \
  -d '{"patient_id":"TEST_001","site_id":"SITE_001","visit_date":"2025-01-15"}'

# Test model serving
curl http://localhost:8000/health
curl -X POST http://localhost:8000/v1/predict \
  -H "Content-Type: application/json" \
  -d '{"model_name":"clinical-risk-model","patient_id":"TEST_001"}'
```

### Performance Benchmarks
- **Ingestion**: 800 msg/s (target: 1000)
- **Processing**: Bronze→Silver <5min, Silver→Gold <30min
- **Features**: Offline <15min, Online <5ms (p99), sync lag <2min
- **Serving**: <100ms (p99 cache-miss), <10ms (p99 cache-hit), 100+ req/s, 70%+ cache hit

---

## Development Workflow

### Project Structure
```
clinical-trials-service/
├── pipeline-manager.sh          # Main orchestration
├── docker-compose.yml           # Service definitions
├── applications/                # Microservices
│   ├── clinical-data-gateway/  # REST API (FastAPI)
│   ├── lab-results-processor/  # Lab processor
│   ├── feature-engineering/    # Feature pipeline
│   ├── model-training/         # ML training
│   └── model-serving/          # Serving API (FastAPI)
├── scripts/                     # Utilities
├── docs/                        # Documentation
├── orchestration/dags/          # Airflow DAGs
├── config/                      # Service configs
└── tests/                       # Test suites
```

### Code Standards
**Python**: PEP 8, ruff (linter), black (formatter), mypy (types), Google-style docstrings
**TypeScript**: ESLint, Prettier, strict mode
**Docker**: Multi-stage builds, HEALTHCHECK directive
**Bash**: ShellCheck, `set -euo pipefail`

### Git Workflow
**Branches**: `feature/`, `fix/`, `docs/`, `refactor/`, `test/`
**Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
**Example**: `feat(ingestion): Add IBM MQ bridge for legacy systems`

### Development Cycle
```bash
# Start level
./pipeline-manager.sh --start --level 3

# Make changes in applications/

# Rebuild
./pipeline-manager.sh --restart-rebuild --level 3

# Check health/logs
./pipeline-manager.sh -hl --level 3
```

### HIPAA Compliance
- Never log patient identifiers (use correlation IDs)
- Audit all data access (timestamp, user, action, resource)
- TLS 1.3 for external communication
- Encrypt sensitive data at rest
- Implement RBAC for API endpoints
- Follow retention policies (Bronze: indefinite, Silver: 90d, Gold: 30d)

---

## Troubleshooting

### Common Issues

**Services Won't Start**:
```bash
# Check port conflicts
netstat -tuln | grep -E ':(9001|5432|6379|9092|8080)'
# Kill conflicting processes
sudo lsof -ti :9000 | xargs sudo kill -9
# Clean Docker
docker system prune -a --volumes
```

**Data Not Flowing**:
```bash
# Check Kafka topics
docker compose exec kafka kafka-topics --list --bootstrap-server localhost:9092
# Check consumer lag
docker compose exec kafka kafka-consumer-groups --describe --group clinical-consumers --bootstrap-server localhost:9092
# Restart Spark
docker compose restart spark-master spark-worker-1
```

**Feature Store Inconsistencies**:
```bash
# Compare stores
./pipeline-manager.sh --compare-stores $(date +%Y-%m-%d) --level 3
# Manual sync
docker compose exec feature-engineering python sync_stores.py --date $(date +%Y-%m-%d)
# Clear and resync
docker compose exec redis redis-cli FLUSHDB && docker compose restart feature-engineering
```

**Model Serving Errors**:
```bash
# Check health
curl http://localhost:8000/health && curl http://localhost:8000/ready
# View logs
docker compose logs model-serving
# Restart
docker compose restart model-serving
```

### Debugging Tools
```bash
# Bash into container
docker compose exec <service> bash

# Test connectivity
docker compose exec <service> ping <other-service>

# Query PostgreSQL
docker compose exec postgres psql -U mlflow -d mlflow_db -c "SELECT * FROM experiments;"

# Browse Redis
docker compose exec redis redis-cli KEYS "feature:*"

# List MinIO objects
docker compose exec minio mc ls local/bronze/
```

---

## Roadmap

### Immediate (2 weeks)
**Complete Level 5**: Finalize DAGs, error handling, alerting (email/Slack), documentation, CI/CD for DAGs

### Mid-Term (3-6 months)
**Level 6 - Observability** (4 weeks):
- Deploy Prometheus + Grafana
- Configure exporters (Node, Kafka, Postgres, Redis, custom)
- Create 5 core dashboards (Platform, Pipeline, Features, ML, Resources)
- Set up OpenSearch + Filebeat
- Define alerting rules (Critical: PagerDuty, Warning: Slack)

**Level 7 - Platform Engineering** (8 weeks):
- Migrate to Kubernetes
- Deploy ArgoCD (GitOps)
- Install Istio/Linkerd (service mesh, mTLS)
- Implement Argo Rollouts (canary, blue-green)
- Create GitHub Actions CI/CD

**Level 8 - Security Testing** (4 weeks):
- Integrate SAST/DAST (SonarQube, OWASP ZAP)
- Deploy Metasploit + Burp Suite
- Create penetration testing scenarios
- Establish vulnerability management
- Achieve HIPAA compliance certification

### Long-Term (6-12 months)
- A/B testing framework
- Online learning pipelines
- Automated retraining
- Model explainability (SHAP/LIME)
- Federated learning
- Data profiling dashboards
- Drift detection automation
- Feature caching optimization
- Pre-commit hooks
- Development containers

---

## Useful Commands

### Docker Compose
```bash
docker compose up -d                          # Start services
docker compose --profile data-ingestion up -d # Start specific profile
docker compose ps                             # List containers
docker compose logs -f <service>              # Tail logs
docker compose restart <service>              # Restart
docker compose down [-v]                      # Stop [and remove volumes]
docker compose scale spark-worker=3           # Scale service
```

### Kafka
```bash
# Inside kafka container
kafka-topics --list --bootstrap-server localhost:9092
kafka-topics --describe --topic <topic> --bootstrap-server localhost:9092
kafka-console-consumer --bootstrap-server localhost:9092 --topic <topic> --from-beginning
kafka-consumer-groups --describe --group <group> --bootstrap-server localhost:9092
```

### Redis
```bash
# Inside redis-cli
PING                                # Test connection
SCAN 0 MATCH feature:* COUNT 100    # Scan keys
HGETALL <key>                       # Get hash
TTL <key>                           # Get TTL
DBSIZE                              # Count keys
INFO                                # Server info
```

### PostgreSQL
```bash
# Inside psql
\l          # List databases
\c <db>     # Connect to database
\dt         # List tables
\d <table>  # Describe table
```

### MinIO
```bash
# Using mc (MinIO Client)
mc ls local/bronze/                      # List objects
mc cp file local/bronze/                 # Upload
mc cp local/bronze/file /path/           # Download
```

### Spark
```bash
spark-submit --master spark://spark-master:7077 script.py
pyspark                                  # PySpark shell
spark-sql -e "SELECT * FROM table;"      # Spark SQL
```

### MLflow
```bash
mlflow ui --backend-store-uri postgresql://mlflow:mlflow@localhost:5432/mlflow_db
mlflow models serve -m "models:/my-model/production" -p 5001
```

### Airflow
```bash
airflow dags list                                    # List DAGs
airflow dags trigger <dag-id>                        # Trigger DAG
airflow dags pause/unpause <dag-id>                  # Pause/unpause
airflow tasks test <dag-id> <task-id> <exec-date>   # Test task
```

---

## Port Reference

| Port | Service | Purpose |
|------|---------|---------|
| 5432 | PostgreSQL | MLflow + Airflow metadata |
| 6379 | Redis | Online features + cache |
| 5540 | Redis Insight | Redis GUI |
| 9000 | MinIO S3 API | Object storage |
| 9001 | MinIO Console | MinIO web UI |
| 9092 | Kafka | Kafka broker |
| 2181 | Zookeeper | Kafka coordination |
| 8090 | Kafka UI | Kafka web UI |
| 8001 | Clinical Gateway | Data ingestion API |
| 8080 | Spark Master | Spark monitoring |
| 7077 | Spark Master | Spark cluster |
| 5000 | MLflow | Experiment tracking |
| 8000 | Model Serving | Prediction endpoint |
| 8081 | Airflow/Spark Worker | Airflow UI / Worker UI |
| 5555 | Flower | Celery monitoring |

---

## Security Configuration

**Authentication**: JWT (1hr expiration), username/password (admin consoles), mTLS (planned)
**Authorization**: RBAC (Admin, Data Scientist, Operator, Viewer)
**Encryption**: TLS 1.3 (external), AES-256 (at rest - production)
**Audit**: All access logged (timestamp, user, action, resource, correlation ID), immutable logs
**Network**: Docker network isolation, firewall rules
**Compliance**: HIPAA Security Rule, SOC 2 Type II (planned), GDPR

---

## Resources

**Documentation**:
- [Apache Spark](https://spark.apache.org/docs/latest/)
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [MLflow](https://mlflow.org/docs/latest/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Docker Compose](https://docs.docker.com/compose/)

**Guides**:
- Detailed testing: `docs/testing/LEVEL0-4_TEST_GUIDE.md`
- Architecture: `docs/architecture/`
- Runbooks: `docs/runbooks/`

---

**For issues**: Check logs (`./pipeline-manager.sh -l --level <N>`), consult troubleshooting section, or create issue in project repository.
