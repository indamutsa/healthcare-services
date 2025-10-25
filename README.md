# Clinical Trials MLOps Platform

Modern level-based Clinical MLOps environment for managing clinical trial data from ingestion through model serving and observability. The stack combines real-time messaging, distributed processing, feature engineering, ML training, inference, and operational tooling—each grouped into hierarchical levels that can be started, tested, and iterated independently.

## Table of Contents
- [Platform Overview](#platform-overview)
- [Level-Based Architecture](#level-based-architecture)
- [Data Flow](#data-flow)
- [Getting Started](#getting-started)
- [Managing the Pipeline](#managing-the-pipeline)
- [Operational Dashboards](#operational-dashboards)
- [Testing and Validation](#testing-and-validation)
- [Developer Toolkit](#developer-toolkit)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

## Platform Overview
The platform orchestrates clinical trial data through resilient services and storage layers backed by Docker Compose. Levels build on each other—starting a higher level automatically includes all dependencies below it. This makes it easy to iterate on a single capability (e.g., feature engineering) without hand-managing the entire stack.

Key foundations:
- Container-native workflow with Docker Compose profiles
- Hierarchical orchestration via `pipeline-manager.sh`
- Consistent data lifecycle across raw, processed, feature, and prediction layers
- Real services only—no mocks or placeholders

## Level-Based Architecture

| Level | Name | Key Services | Compose Profile | Status |
| ----- | ---- | ------------ | ---------------- | ------ |
| 0 | Infrastructure | MinIO, PostgreSQL (mlflow/airflow), Redis, Kafka, Zookeeper, Kafka UI, Redis Insight | *(base)* | Implemented |
| 1 | Data Ingestion | Kafka producer/consumer, IBM MQ bridge, Clinical Data Gateway, Lab Results Processor | `data-ingestion` | Implemented |
| 2 | Data Processing | Spark master/worker, streaming and batch jobs | `data-processing` | Implemented |
| 3 | Feature Engineering | Feature engineering service, offline (MinIO) + online (Redis) feature stores, comparison utilities | `features` | Implemented |
| 4 | ML Pipeline | MLflow tracking server, training jobs, model serving API with Redis cache | `ml-pipeline` | Implemented |
| 5 | Orchestration | Airflow scheduler, webserver, workers | `orchestration` | In Progress |
| 6 | Observability | Prometheus, Grafana, OpenSearch Dashboards, Data Prepper, Filebeat | `observability` | Planned |
| 7 | Platform Engineering | ArgoCD, GitHub Actions runners, Istio mesh, Kubernetes, Argo Rollouts, DAST/SAST tooling | `platform` | Planned |
| 8 | Security Testing | Metasploit, active penetration testing harness | `security` | Planned |

> Levels 0-4 are production-ready today. Higher levels are tracked in the roadmap and will use the same hierarchical management model once delivered.

## Data Flow
1. **Clinical Site Intake** – REST API receives validated payloads, pushes messages into IBM MQ and Kafka.
2. **Streaming Ingestion (Level 1)** – Producers and consumers populate Bronze storage in MinIO; events remain immutable.
3. **Processing (Level 2)** – Spark streaming and batch jobs cleanse, deduplicate, standardize, and publish Silver parquet datasets.
4. **Feature Engineering (Level 3)** – Pipelines derive 120+ temporal and contextual features, persisting to both offline parquet (MinIO) and online Redis structures.
5. **ML Pipeline (Level 4)** – Training jobs load latest offline partitions, log experiments to MLflow, and promote models. Model-serving exposes `/v1/predict` with Redis-backed caching and MLflow registry integration.
6. **Observability & Orchestration** – Upcoming levels extend automation, dashboards, and continuous delivery.

## Getting Started

### Prerequisites
- Docker 24+
- Docker Compose v2
- Python 3.11+ (for local utilities)
- `jq` and `curl` for API validation

### Environment Setup
```bash
# Optional helpers (improves terminal + installs dependencies)
chmod +x enhance-terminal.sh alpine-setup.sh
./enhance-terminal.sh
./alpine-setup.sh

# Ensure the manager script is executable
chmod +x pipeline-manager.sh
```

### First Run
```bash
# Start core infrastructure (MinIO, Postgres, Redis, Kafka…)
./pipeline-manager.sh --start --level 0

# Check status and summary output
./pipeline-manager.sh --summary --level 0

# Bring up the entire ML pipeline stack (levels 0-4)
./pipeline-manager.sh --start --level 4
```

## Managing the Pipeline
`pipeline-manager.sh` is the orchestration entrypoint. It understands combined short flags, hierarchical level selection, and feature-engineering utilities.

### Management Commands (Mutually Exclusive)
- `--start` – `docker compose up -d` for the selected level and dependencies
- `--stop` – `docker compose down -v` (volumes removed for the targeted levels)
- `--restart-rebuild` – Stop, rebuild images without cache, start again
- `--clean` – Full cleanup (removes images and orphaned resources)

### Information Commands (Composable: e.g., `-vhso`)
- `-v`/`--visualize` – High-level topology diagrams
- `-h`/`--health-check` – Aggregated health probes per level
- `-l`/`--logs` – Tail service logs
- `-o`/`--open` – Print service URLs
- `-s`/`--summary` – Counts and status per level
- `-d`/`--demo-data` – Show sample payloads and generators

### Level Selection
- `--level <0-8>` – Target level (includes all lower dependencies)
- `--level all` – Entire stack

### Level 3 Feature Store Utilities
- `--compare-stores [DATE]` – Offline vs online feature parity
- `--inspect-feature-volume [NAME]` – Volume introspection
- `--monitor-feature-pipeline [DATE]` – End-to-end pipeline monitor
- `--query-offline-features [DATE]` – Inspect parquet partitions
- `--query-online-features [PATIENT]` – Fetch Redis feature payloads

> Feature utilities require `--level 3` or higher. The script enforces the constraint automatically.

### Example Workflows
```bash
# Start infrastructure + ingestion
./pipeline-manager.sh --start --level 1

# Monitor Spark processing with health + logs
./pipeline-manager.sh --health-check --logs --level 2

# Run the ML pipeline with feature checks
./pipeline-manager.sh --start -h -o --level 4
./pipeline-manager.sh --compare-stores --level 3

# Tear down Levels 2-4 but keep infrastructure running
./pipeline-manager.sh --stop --level 4

# Full clean reset
./pipeline-manager.sh --clean --level all
```

## Operational Dashboards
| Service | URL | Level | Notes |
| ------- | --- | ----- | ----- |
| MinIO Console | http://localhost:9001 | 0 | `minioadmin` / `minioadmin` |
| Kafka UI | http://localhost:8090 | 0 | Inspect topics and consumers |
| Redis Insight | http://localhost:5540 | 0 | Online feature debugging |
| Spark Master | http://localhost:8080 | 2 | Streaming and batch monitoring |
| Model Serving API | http://localhost:8000 | 4 | `/health`, `/ready`, `/v1/predict` |
| MLflow Tracking UI | http://localhost:5000 | 4 | Experiments and model registry |
| Airflow Webserver | http://localhost:8081 | 5 | *(coming soon)* |
| Prometheus | http://localhost:9090 | 6 | *(planned)* |
| Grafana | http://localhost:3000 | 6 | *(planned)* |
| OpenSearch Dashboards | http://localhost:5601 | 6 | *(planned)* |

## Testing and Validation
- **Smoke Tests:** each management command prints summary, health checks, and active containers. Start with `./pipeline-manager.sh -s -h --level 4`.
- **End-to-End Guide:** `docs/testing/LEVEL0-4_TEST_GUIDE.md` walks through validation for services, data layers, and API endpoints.
- **Model Serving Verification:** Exercise `/v1/predict` with representative payloads. Caching behavior can be confirmed via repeated calls (`"cached": true`).
- **Data Store Inspection:** Use the auxiliary commands (MinIO client, Spark SQL, Redis Insight) outlined in the testing guide.

## Developer Toolkit
```
clinical-trials-service/
├── pipeline-manager.sh         # Level-based orchestration
├── docker-compose.yml          # Service definitions + profiles
├── applications/               # Microservices, training, serving
├── scripts/                    # Common utilities (compose helpers, health probes)
├── docs/                       # Architecture, testing, runbooks
│   └── testing/LEVEL0-4_TEST_GUIDE.md
├── data/                       # Local artifacts, parquet staging
├── operations/                 # Demo generators and automation
└── orchestration/              # Airflow DAGs (WIP)
```

### Frequently Used Commands
```bash
# Build project-specific images
docker compose build

# Lint Python applications
ruff check applications/model-serving

# Run training job on demand
docker compose --profile ml-pipeline run --rm ml-training python train.py

# Inspect latest feature parquet partition (inside Spark container)
docker compose --profile data-processing exec spark-batch spark-sql \
  -e "SELECT COUNT(*), date FROM features_offline GROUP BY date ORDER BY date DESC LIMIT 5;"
```

## Roadmap
- **Level 5 (Airflow):** finalize DAGs for ingestion → processing → feature sync, add Airflow health checks to the manager.
- **Level 6 (Observability):** integrate Prometheus exporters, Grafana dashboards, OpenSearch pipeline.
- **Level 7 (Platform):** codify GitOps workflows, service mesh experiments, progressive delivery with Argo Rollouts.
- **Level 8 (Security):** staged vulnerability injection, automated penetration scenarios, blue/green validation.

Progress is tracked in the issue board. Contributions and design discussions are welcome—see the next section for guidelines.

## Contributing
1. Fork the repository and branch off `main`.
2. Run `./pipeline-manager.sh --start --level 4` to ensure the ML pipeline works with your changes.
3. Add tests or update `docs/testing/LEVEL0-4_TEST_GUIDE.md` when behavior changes.
4. Open a pull request with a concise description, screenshots/logs if relevant, and verification steps.

The platform targets HIPAA-aligned workflows: anonymized identifiers, audit-ready logging, strong validation, and transport security. Please keep these standards in mind when contributing new features.
