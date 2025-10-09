## 🧠 `spark/` — Spark Services for Clinical MLOps

This folder contains the Docker setup for **Apache Spark 3.5.4 (Java 17)** used in the Clinical MLOps data pipeline.

---

### ⚙️ Components

| Service             | Purpose                                                                                |
| ------------------- | -------------------------------------------------------------------------------------- |
| **spark-master**    | Spark master node — web UI at [http://localhost:8080](http://localhost:8080)           |
| **spark-worker**    | Worker node executing distributed tasks                                                |
| **spark-streaming** | Real-time processor consuming Kafka topics and writing to the Bronze → Silver pipeline |
| **spark-batch**     | Batch processor converting Bronze → Silver data hourly (continuous loop)               |

---

### 🚀 Build & Run

```bash
# Build all Spark images
docker compose build spark-master spark-worker spark-streaming spark-batch

# Start Spark cluster
docker compose up -d spark-master spark-worker spark-streaming spark-batch
```

Check container status:

```bash
docker ps
```

View logs (continuous stream):

```bash
docker logs -f spark-batch
```

---

### 🔁 Continuous Batch Processor

The `spark-batch` service now runs continuously using
[`entrypoint.sh`](./entrypoint.sh).
It executes the batch job every `INTERVAL_MINUTES` (default = 60 min).

Change interval:

```bash
# Example: run every 30 minutes
docker compose up -d spark-batch
# or override at runtime
docker run -e INTERVAL_MINUTES=30 clinical-mlops/spark-batch
```

You’ll see log messages like:

```
⏰ Starting batch job at Thu Oct 09 17:00:00
✅ Batch completed at Thu Oct 09 17:01:10
Sleeping 60 minutes before next run...
```

---

### 🧹 Maintenance Commands

```bash
# Stop Spark containers
docker compose stop spark-master spark-worker spark-streaming spark-batch

# Remove Spark containers + volumes
docker compose down -v

# View Spark UI
open http://localhost:8080   # Master UI
open http://localhost:4040   # Driver UI (active batch job)
```

---

### 🧩 Project Structure

```
spark/
├── Dockerfile                # Base image for Spark Batch
├── entrypoint.sh             # Looping scheduler (runs spark-submit every hour)
├── jobs/                     # Python Spark jobs (e.g., bronze_to_silver_batch.py)
├── transformations/          # Data transformation logic
├── utils/                    # Helper functions and connectors
└── README.md                 # ← you are here
```

---

### ✅ Notes

* All jobs use the MinIO endpoint `http://minio:9000` via the `s3a://` connector.
* Update credentials or paths in `entrypoint.sh` if MinIO changes.
* Future integration: Airflow or Dagster can trigger `spark-batch` on a schedule instead of the internal loop.

---
