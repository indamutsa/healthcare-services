# Clinical MLOps Pipeline – Levels 0‒4 Test Guide

This guide walks through validation of the Clinical MLOps stack from infrastructure (Level 0) through the ML pipeline (Level 4). Work through sections sequentially—each level builds on the previous one.

---

## 1. Global Prerequisites

- Run commands from the repository root (`/workspaces/clinical-trials-service`).
- Ensure Docker Desktop (or daemon) is running with file sharing enabled for the workspace.
- Recommended: `docker system prune -f` before the first full run to reclaim disk space.
- Stop all existing services before clean runs: `docker compose down --remove-orphans`.

Key helper:  
`./pipeline-manager.sh --help` – refresh command list and supported flags.

---

## 2. Level 0 – Infrastructure

**Goal:** Validate core services (MinIO, Postgres instances, Redis, Kafka, Zookeeper, Kafka UI).

1. **Start**  
   `./pipeline-manager.sh --start --level 0`
2. **Status**  
   `./pipeline-manager.sh -s --level 0` – expect 8/8 services running.
3. **Health**  
   `./pipeline-manager.sh -h --level 0`
4. **Logs (optional)**  
   `./pipeline-manager.sh -l --level 0` – tails combined logs.
5. **Dashboards / URLs**  
   - MinIO Console: http://localhost:9001  
   - Redis Insight: http://localhost:5540  
   - Kafka UI: http://localhost:8080
6. **Data spot-check**  
   `docker exec minio mc ls myminio` – confirm expected buckets (e.g., `clinical-mlops`).

Teardown: `./pipeline-manager.sh --stop --level 0` (removes volumes—infra only—if needed).

---

## 3. Level 1 – Data Ingestion

**Goal:** Confirm Kafka producers/consumers, IBM MQ bridge, gateway, lab processor.

1. **Start**  
   `./pipeline-manager.sh --start -h --level 1` – automatically ensures Level 0 is up and runs health checks.
2. **Status**  
   `./pipeline-manager.sh -s --level 1` – look for 6/6 services.
3. **Health**  
   `./pipeline-manager.sh -h --level 1`
4. **Logs**  
   `./pipeline-manager.sh -l --level 1` – watch producer/consumer flow.
5. **Visualization**  
   `./pipeline-manager.sh -v --level 1` – quick dependency view.
6. **Kafka topic validation**  
   ```
   docker exec kafka kafka-topics --bootstrap-server kafka:9092 --list
   docker exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --all-groups --describe
   ```
7. **Sample payload check**  
   `docker logs clinical-data-generator | tail -n 20` – confirm messages publishing.

---

## 4. Level 2 – Data Processing

**Goal:** Validate Spark batch/streaming jobs and cluster health.

1. **Start**  
   `./pipeline-manager.sh --start --level 2`
2. **Status**  
   `./pipeline-manager.sh -s --level 2` – expect 4/4 services (spark-master, worker, streaming, batch).
3. **Health**  
   `./pipeline-manager.sh -h --level 2`
4. **Logs**  
   `./pipeline-manager.sh -l --level 2`
5. **Spark UI**  
   Spark master web UI: http://localhost:8081
6. **Spark SQL (MinIO-backed table)**  
   ```
   docker exec -it spark-master spark-sql \
     --packages org.apache.hadoop:hadoop-aws:3.3.4 \
     -e "SELECT patient_id, adverse_event_flag FROM clinical_features LIMIT 10;"
   ```
   Adjust query/table names to match latest feature outputs.
7. **Streaming checkpoint**  
   `docker exec spark-streaming ls -R /opt/spark/checkpoints` – verify checkpoint files appear.

---

## 5. Level 3 – Feature Engineering

**Goal:** Validate feature materialization, store parity, and exploration utilities.

1. **Start**  
   `./pipeline-manager.sh --start --level 3`
2. **Status**  
   `./pipeline-manager.sh -s --level 3` – single `feature-engineering` container should show running.
3. **Health**  
   `./pipeline-manager.sh -h --level 3`
4. **Feature tooling commands**
   - Compare offline vs online stores: `./pipeline-manager.sh --compare-stores --level 3`
   - Inspect feature volume: `./pipeline-manager.sh --inspect-feature-volume clinical-trials-service_feature-data --level 3`
   - Query offline partition: `./pipeline-manager.sh --query-offline-features 2025-10-25 --level 3`
   - Query online features (Redis): `./pipeline-manager.sh --query-online-features PATIENT_001 --level 3`
5. **Manual checks**
   - MinIO: `docker exec minio mc ls myminio/clinical-mlops/features/offline/`
   - Redis: `docker exec redis redis-cli HGETALL feature:online:PATIENT_001`

---

## 6. Level 4 – ML Pipeline (MLflow, Training, Model Serving)

**Goal:** Validate tracking server, training run, model serving API, and caching.

1. **Start**  
   `./pipeline-manager.sh --start --level 4` – cascades Levels 0–3 automatically.
2. **Status**  
   `./pipeline-manager.sh -s --level 4` – expect both `mlflow-server` and `model-serving` running.
3. **Health**  
   `./pipeline-manager.sh --health-check --level 4`
4. **Dashboards / URLs**  
   - MLflow UI: http://localhost:5050  
   - Model Serving API docs: http://localhost:8000/docs  
   - Model Serving health: http://localhost:8000/health
5. **Training**  
   `./pipeline-manager.sh --level 4 --run-training`  
   Tail logs: `docker logs -f ml-training`
6. **Model Serving smoke test**
   ```bash
   payload=$(python3 tests/helpers/sample_payload.py)   # or craft manually
   curl -s -X POST http://localhost:8000/v1/predict \
     -H "Content-Type: application/json" \
     -d "$payload" | jq
   ```
   Repeat the request to confirm `"cached": true`.
7. **Cache and registry checks**
   - `docker exec redis redis-cli --scan --pattern "model-serving:*" | head`
   - `docker exec mlflow-server curl -s http://localhost:5000/api/2.0/mlflow/registered-models/list | jq`

Teardown (if required):
- Stop ML layer only: `./pipeline-manager.sh --stop --level 4`
- Full rebuild: `./pipeline-manager.sh --restart-rebuild --level 4`

---

## 7. Cross-Level Regression Steps

- **Summary sweep:** `for lvl in 0 1 2 3 4; do ./pipeline-manager.sh -s --level $lvl; done`
- **Combined info flags:** `./pipeline-manager.sh -vhso --level 4` (verify CLI output formatting).
- **Cascade stop check:** `./pipeline-manager.sh --stop --level 4` followed by `docker ps` ensures lower levels halt.
- **Clean slate:** `./pipeline-manager.sh --clean --level all` (interactive confirmation) before rerunning from Level 0.

---

## 8. Troubleshooting Tips

- Health check failures log the failing command—rerun it manually (copy/paste from CLI output) for detailed errors.
- If Docker volume mounts fail (e.g., during training), confirm shared folders in Docker Desktop settings.
- For long-running starts, increase compose timeout: `COMPOSE_HTTP_TIMEOUT=300 ./pipeline-manager.sh --start --level 4`.
- Use `docker compose --profile ml-pipeline logs -f mlflow-server` for deeper MLflow diagnostics.

---

## 9. Next Steps

Once Levels 0–4 are verified:
- Integrate automated tests (pytest) for `applications/ml-training` data loader exclusions.
- Add integration tests for `applications/model-serving` cache miss/hit behaviour.
- Prepare Level 5 (Airflow) validation once orchestration services are available.

