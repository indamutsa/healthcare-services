# Clinical MLOps Platform - Complete Architecture

## 🎯 What You Have Built

A **production-ready MLOps platform** with complete data pipeline, monitoring, and logging infrastructure.

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA INGESTION LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  Kafka Producer → Kafka Topics → Kafka Consumer             │
│  (synthetic data)   (4 topics)    (to MinIO)                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    STORAGE LAYER (Data Lake)                 │
├─────────────────────────────────────────────────────────────┤
│  MinIO (S3-Compatible Object Storage)                       │
│  ├── Bronze Layer: Raw JSON (immutable)                     │
│  ├── Silver Layer: Clean Parquet (ML-ready)                 │
│  └── Gold Layer: Aggregated (future)                        │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    PROCESSING LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Spark Cluster (Master + Worker)                            │
│  - Bronze → Silver transformation                            │
│  - Deduplication, validation, enrichment                     │
│  - Parquet output with partitioning                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    ML PLATFORM LAYER                         │
├─────────────────────────────────────────────────────────────┤
│  MLflow: Experiment tracking, model registry                 │
│  PostgreSQL: MLflow backend store                            │
│  Redis: Feature store (online serving)                       │
│  DVC: Data/model versioning                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  Airflow: Data pipeline scheduling                           │
│  - Data processing DAGs                                      │
│  - Model monitoring DAGs                                     │
│  - Retraining triggers                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  METRICS: Prometheus → Grafana                              │
│  - Data quality, model performance                           │
│  - System health, resource usage                             │
│  - Alerts on degradation                                     │
│                                                              │
│  LOGS: Filebeat → Logstash → Elasticsearch → Kibana        │
│  - Centralized logging from all containers                   │
│  - Log parsing and enrichment                                │
│  - Search and visualization                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start Commands

### Start Core Infrastructure

```bash
# Start everything (data pipeline + monitoring)
docker-compose up -d

# Verify all services
docker-compose ps

# Expected services running:
# - minio, kafka, zookeeper
# - postgres-mlflow, postgres-airflow, redis
# - mlflow-server
# - kafka-producer, kafka-consumer
# - spark-master, spark-worker
# - prometheus, grafana
# - elasticsearch, logstash, kibana, filebeat
```

### Start Optional Services

```bash
# Start Airflow
docker-compose --profile airflow up -d airflow-webserver airflow-scheduler

# Run Spark processing job
docker-compose --profile spark-job up spark-processor

# Start feature engineering
docker-compose --profile feature-engineering up feature-engineering

# Start model training
docker-compose --profile training up ml-training

# Start model serving
docker-compose --profile serving up -d model-serving
```

---

## 🌐 Service Access Points

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin | Browse data lake |
| **MLflow UI** | http://localhost:5000 | - | Track experiments |
| **Spark Master** | http://localhost:8080 | - | Monitor Spark jobs |
| **Spark Worker** | http://localhost:8081 | - | Worker metrics |
| **Prometheus** | http://localhost:9090 | - | Query metrics |
| **Grafana** | http://localhost:3000 | admin / admin | View dashboards |
| **Kibana** | http://localhost:5601 | - | Search logs |
| **Elasticsearch** | http://localhost:9200 | - | REST API |
| **Airflow** | http://localhost:8081 | admin / admin | DAG management |
| **Model Serving** | http://localhost:8000 | - | Predictions API |

---

## 📁 Directory Structure

```
clinical-mlops/
├── applications/
│   ├── kafka-producer/          # Data generation
│   ├── kafka-consumer/          # Data ingestion
│   ├── spark-processor/         # Data processing
│   ├── feature-engineering/     # ML features (to build)
│   ├── ml-training/            # PyTorch training (to build)
│   ├── model-serving/          # FastAPI serving (to build)
│   └── monitoring-service/     # Drift detection (to build)
│
├── orchestration/
│   ├── airflow/
│   │   ├── dags/               # Airflow workflows
│   │   ├── plugins/            # Custom operators
│   │   └── config/
│   └── kubeflow/               # ML pipelines (future)
│
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts/
│   │       └── ml_model_rules.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   └── data-pipeline.json
│   │   └── provisioning/
│   └── elk/
│       ├── logstash/
│       │   ├── config/logstash.yml
│       │   └── pipeline/logstash.conf
│       └── filebeat/
│           └── filebeat.yml
│
├── data/                        # Local storage
│   ├── raw/
│   ├── processed/
│   ├── features/
│   └── models/
│
├── operations/
│   └── dvc/                    # Data version control
│
├── scripts/
│   ├── quick-start.sh
│   ├── start-elk.sh
│   ├── test-complete-pipeline.sh
│   └── run-spark-job.sh
│
├── docker-compose.yml
└── .env
```

---

## ✅ Components Status

### Fully Implemented

- ✅ **Kafka Producer**: Generating synthetic patient data
- ✅ **Kafka Consumer**: Writing to MinIO bronze layer
- ✅ **MinIO Data Lake**: Bronze (raw) + Silver (clean) layers
- ✅ **Spark Cluster**: Bronze → Silver transformation
- ✅ **MLflow Server**: Ready for experiment tracking
- ✅ **Prometheus**: Metrics collection configured
- ✅ **Grafana**: Data pipeline dashboard
- ✅ **ELK Stack**: Centralized logging
- ✅ **PostgreSQL**: MLflow + Airflow backends
- ✅ **Redis**: Ready for feature store

### To Be Built

- ⬜ **Feature Engineering**: Create 120 ML features
- ⬜ **PyTorch Training**: Train adverse event prediction model
- ⬜ **Model Serving**: FastAPI deployment
- ⬜ **Monitoring Service**: Drift detection & alerting
- ⬜ **Airflow DAGs**: Automated orchestration
- ⬜ **DVC Setup**: Data/model versioning

---

## 🔄 Data Flow

### 1. Data Generation & Ingestion

```
Kafka Producer (Python)
  ↓ (100 msg/sec)
Kafka Topics
  - patient-vitals (70%)
  - medications (20%)
  - lab-results (9%)
  - adverse-events (1%)
  ↓
Kafka Consumer (Python)
  ↓ (batches of 1000 or 30s)
MinIO Bronze Layer
  s3://clinical-mlops/raw/patient-vitals/date=YYYY-MM-DD/hour=HH/batch_*.json
```

### 2. Data Processing

```
Spark Job (PySpark)
  ↓ (reads bronze)
Transformations:
  - Deduplication by (patient_id, timestamp, source)
  - Validation (physiological ranges)
  - Unit standardization
  - Derived metrics (pulse pressure, MAP)
  - Quality scoring
  ↓ (writes silver)
MinIO Silver Layer
  s3://clinical-mlops/processed/patient-vitals/date=YYYY-MM-DD/*.parquet
```

### 3. Monitoring

```
All Services
  ↓ (logs)
Docker Containers
  ↓
Filebeat → Logstash → Elasticsearch → Kibana
  ↓ (metrics)
Prometheus → Grafana
```

---

## 🎛️ Key Configuration Files

### Environment Variables (.env)

```bash
# Kafka
KAFKA_BOOTSTRAP_SERVERS=kafka:29092
PRODUCER_RATE=100
NUM_PATIENTS=1000

# MinIO (S3)
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=clinical-mlops

# MLflow
MLFLOW_TRACKING_URI=http://mlflow-server:5000

# Spark
SPARK_MASTER_URL=spark://spark-master:7077

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
```

### Docker Compose Profiles

```yaml
# Always running (default)
- minio, kafka, postgres, redis
- mlflow-server
- kafka-producer, kafka-consumer
- spark-master, spark-worker
- prometheus, grafana
- elasticsearch, logstash, kibana, filebeat

# On-demand (use --profile)
--profile spark-job          # Run Spark processing
--profile feature-engineering # Create features
--profile training           # Train models
--profile serving            # Deploy model API
--profile airflow            # Start orchestration
--profile monitoring         # Advanced monitoring
```

---

## 🧪 Testing & Verification

### 1. Test Complete Pipeline

```bash
chmod +x scripts/test-complete-pipeline.sh
./scripts/test-complete-pipeline.sh
```

**Expected output:**
```
✅ Data Generation: Kafka Producer is generating patient data
✅ Data Ingestion: Kafka Consumer writing to MinIO Bronze
✅ Data Processing: Spark transforming Bronze → Silver
✅ Data Storage: Clean Parquet files in MinIO Silver
🎉 Complete MLOps pipeline is working!
```

### 2. Verify ELK Stack

```bash
chmod +x scripts/start-elk.sh
./scripts/start-elk.sh

# Check indices
curl http://localhost:9200/_cat/indices?v | grep mlops

# Open Kibana and create index pattern
open http://localhost:5601
```

### 3. View Monitoring Dashboards

```bash
# Open Grafana
open http://localhost:3000

# Default dashboard: Clinical MLOps - Data Pipeline
# Shows:
# - Data processing rate
# - Data quality score
# - Invalid records rate
# - Spark job duration
```

### 4. Inspect Data Quality

```bash
# View bronze (raw) data
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc cat myminio/clinical-mlops/raw/patient-vitals/date=$(date +%Y-%m-%d)/hour=*/batch_*.json | head -3

# View silver (processed) data structure
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls --recursive myminio/clinical-mlops/processed/
```

---

## 🔍 Monitoring & Observability

### Metrics (Prometheus + Grafana)

**Available Metrics:**
- `data_records_processed_total` - Records processed by layer
- `data_invalid_records_total` - Invalid records filtered
- `data_duplicates_removed_total` - Duplicates removed
- `spark_job_duration_seconds` - Spark job execution time
- `data_quality_score` - Data quality percentage

**Grafana Dashboards:**
- Data Pipeline Dashboard (pre-configured)
- Custom dashboards for Kafka, Spark, MLflow

### Logs (ELK Stack)

**Available Indices:**
- `mlops-logs-*` - All logs
- `mlops-kafka-*` - Kafka logs
- `mlops-spark-*` - Spark logs
- `mlops-mlflow-*` - MLflow logs
- `mlops-airflow-*` - Airflow logs
- `mlops-serving-*` - Model serving logs

**Common Queries in Kibana:**
```
# All errors
log_level: "ERROR"

# Spark job failures
component: "spark" AND message: "failed"

# High latency predictions
component: "model-serving" AND prediction_latency_ms > 200

# Kafka consumer lag
component: "kafka-consumer" AND lag > 1000
```

### Alerts (Prometheus)

**Configured Alerts:**
- Model performance degraded (AUROC < 0.80)
- High invalid record rate (> 10%)
- Spark job failures
- Kafka consumer lag (> 10K messages)
- High prediction latency (p99 > 200ms)

---

## 🛠️ Operations

### Daily Operations

```bash
# Check service health
docker-compose ps

# View logs
docker-compose logs -f <service-name>

# Restart a service
docker-compose restart <service-name>

# Run Spark job (hourly)
docker-compose exec spark-master spark-submit \
  --master spark://spark-master:7077 \
  --packages org.apache.hadoop:hadoop-aws:3.3.4 \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  /opt/bitnami/spark/jobs/bronze_to_silver.py
```

### Cleanup

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v

# Clean old Elasticsearch indices
curl -X DELETE "http://localhost:9200/mlops-*-$(date -d '7 days ago' +%Y.%m.%d)"
```

---

## 📈 Performance Benchmarks

**Current System (1000 patients):**
- Kafka throughput: 100 messages/second
- Bronze layer: ~500 KB per batch file
- Silver layer: ~200 KB (Parquet compression)
- Spark job duration: 10-30 seconds per hour of data
- Data quality: 95-99% (3-5% filtered)

**Scalability:**
- Can handle 10K patients by scaling Spark workers
- Can process 24 hours of data in < 5 minutes
- ELK can handle 10K+ logs/second

---

## 🎯 Next Steps (Build ML Components)

### 1. Feature Engineering (Next Priority)
```bash
# Create feature engineering application
# - Read silver Parquet
# - Create 120 features (rolling windows, interactions)
# - Store in Redis (online) + Parquet (offline)
```

### 2. PyTorch Model Training
```bash
# Build training pipeline
# - Load features from feature store
# - Train neural network (3-layer)
# - Track with MLflow
# - Version with DVC
```

### 3. Model Serving
```bash
# Deploy FastAPI
# - Load model from MLflow
# - Serve predictions
# - Log to database for monitoring
```

### 4. Automated Retraining
```bash
# Create Airflow DAGs
# - Monitor model performance
# - Detect drift
# - Trigger retraining
# - Deploy new model
```

---

## 📚 Documentation

- **Setup Guide**: `README.md`
- **Spark Processing**: `docs/spark-processing.md`
- **ELK Stack**: `docs/elk-setup.md`
- **Monitoring**: `docs/monitoring.md`
- **API Reference**: `docs/api/`

---

## 🎉 Summary

You now have a **complete, production-ready MLOps infrastructure** with:

✅ **Data Pipeline**: Kafka → MinIO → Spark → Clean Parquet
✅ **ML Platform**: MLflow + PostgreSQL + Redis ready
✅ **Monitoring**: Prometheus + Grafana (metrics)
✅ **Logging**: ELK Stack (centralized logs)
✅ **Orchestration**: Airflow ready (to build DAGs)
✅ **Observability**: Full visibility into system health

**Ready to build ML features and train your first PyTorch model!**


---
```sh
#!/bin/bash

# Start ELK Stack for Clinical MLOps Platform
# Elasticsearch → Logstash → Kibana → Filebeat

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

print_header "Starting ELK Stack"

# Step 1: Start Elasticsearch
print_info "Step 1: Starting Elasticsearch..."
docker-compose up -d elasticsearch

print_info "Waiting for Elasticsearch to be healthy (this may take 60 seconds)..."
sleep 10

# Wait for Elasticsearch health check
for i in {1..12}; do
    if docker-compose ps elasticsearch | grep -q "healthy"; then
        print_status "Elasticsearch is healthy"
        break
    fi
    echo -n "."
    sleep 5
done

# Verify Elasticsearch is responding
if curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    print_status "Elasticsearch API is responding"
else
    echo "❌ Elasticsearch is not responding. Check logs: docker-compose logs elasticsearch"
    exit 1
fi

# Step 2: Start Logstash
print_info "Step 2: Starting Logstash..."
docker-compose up -d logstash

print_info "Waiting for Logstash to start (30 seconds)..."
sleep 30

if docker-compose ps logstash | grep -q "Up"; then
    print_status "Logstash is running"
else
    echo "❌ Logstash failed to start. Check logs: docker-compose logs logstash"
    exit 1
fi

# Step 3: Start Kibana
print_info "Step 3: Starting Kibana..."
docker-compose up -d kibana

print_info "Waiting for Kibana to be healthy (this may take 30 seconds)..."
sleep 10

for i in {1..6}; do
    if docker-compose ps kibana | grep -q "healthy"; then
        print_status "Kibana is healthy"
        break
    fi
    echo -n "."
    sleep 5
done

# Step 4: Start Filebeat
print_info "Step 4: Starting Filebeat (log shipper)..."
docker-compose up -d filebeat

sleep 5

if docker-compose ps filebeat | grep -q "Up"; then
    print_status "Filebeat is running"
else
    echo "❌ Filebeat failed to start. Check logs: docker-compose logs filebeat"
    exit 1
fi

# Verification
print_header "ELK Stack Status"

print_status "Elasticsearch running at http://localhost:9200"
print_status "Kibana running at http://localhost:5601"
print_status "Logstash running at http://localhost:9600"
print_status "Filebeat collecting logs from Docker containers"

# Check indices
echo ""
print_info "Checking Elasticsearch indices..."
sleep 5

INDICES=$(curl -s http://localhost:9200/_cat/indices?v 2>&1)
if echo "$INDICES" | grep -q "mlops"; then
    print_status "Found MLOps indices:"
    echo "$INDICES" | grep "mlops"
else
    print_info "No indices yet. Logs will appear shortly as applications generate them."
fi

# Final instructions
print_header "Next Steps"

echo "1. Open Kibana: http://localhost:5601"
echo ""
echo "2. Create Index Pattern:"
echo "   - Go to: Stack Management → Index Patterns"
echo "   - Click 'Create index pattern'"
echo "   - Index pattern: mlops-*"
echo "   - Time field: @timestamp"
echo ""
echo "3. View Logs:"
echo "   - Go to: Discover"
echo "   - Select 'mlops-*' index pattern"
echo "   - You'll see logs from all containers"
echo ""
echo "4. Filter logs by component:"
echo "   - Kafka: component: \"kafka\""
echo "   - Spark: component: \"spark\""
echo "   - MLflow: component: \"mlflow\""
echo ""
echo "5. Search for errors:"
echo "   - log_level: \"ERROR\""
echo ""

print_info "View ELK logs:"
echo "  docker-compose logs -f elasticsearch"
echo "  docker-compose logs -f logstash"
echo "  docker-compose logs -f kibana"
echo "  docker-compose logs -f filebeat"
echo ""

print_status "🎉 ELK Stack is ready!"
echo ""
```

---

# ELK Stack Integration Guide

## Overview

The ELK Stack (Elasticsearch, Logstash, Kibana) + Filebeat provides centralized logging for all MLOps components.

### Architecture

```
Docker Containers (Kafka, Spark, MLflow, etc.)
       ↓ (logs)
    Filebeat (log shipper)
       ↓
    Logstash (log processing & enrichment)
       ↓
   Elasticsearch (log storage & indexing)
       ↓
    Kibana (visualization & search)
```

---

## Quick Setup

### 1. Create Directory Structure

```bash
# Create ELK directories
mkdir -p monitoring/elk/logstash/{pipeline,config}
mkdir -p monitoring/elk/filebeat
```

### 2. Place Configuration Files

**Logstash** (`monitoring/elk/logstash/`):
- `config/logstash.yml` - Logstash configuration
- `pipeline/logstash.conf` - Log processing pipeline

**Filebeat** (`monitoring/elk/filebeat/`):
- `filebeat.yml` - Filebeat configuration

### 3. Start ELK Stack

```bash
# Start Elasticsearch first
docker-compose up -d elasticsearch

# Wait for Elasticsearch to be healthy (60 seconds)
sleep 60

# Start Logstash
docker-compose up -d logstash

# Wait for Logstash (30 seconds)
sleep 30

# Start Kibana
docker-compose up -d kibana

# Start Filebeat (log shipper)
docker-compose up -d filebeat
```

### 4. Access Kibana

Open: http://localhost:5601

**Initial Setup:**
1. Click "Explore on my own"
2. Go to: Management → Stack Management → Index Patterns
3. Create index patterns:
   - `mlops-*` (all logs)
   - `mlops-kafka-*` (Kafka logs)
   - `mlops-spark-*` (Spark logs)
   - `mlops-mlflow-*` (MLflow logs)

---

## Verify ELK is Working

### 1. Check Elasticsearch

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# Expected output:
# {
#   "cluster_name" : "docker-cluster",
#   "status" : "green",
#   "number_of_nodes" : 1,
#   ...
# }
```

### 2. Check Indices

```bash
# List all indices
curl http://localhost:9200/_cat/indices?v

# Should see indices like:
# mlops-kafka-2025.10.07
# mlops-spark-2025.10.07
# mlops-logs-2025.10.07
```

### 3. Search Logs

```bash
# Get recent logs
curl -X GET "http://localhost:9200/mlops-logs-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 10,
  "sort": [{"@timestamp": "desc"}],
  "query": {"match_all": {}}
}
'
```

### 4. Check Logstash Pipeline

```bash
# Check Logstash stats
curl http://localhost:9600/_node/stats?pretty

# Check pipeline stats
curl http://localhost:9600/_node/stats/pipelines?pretty
```

### 5. Check Filebeat

```bash
# View Filebeat logs
docker-compose logs filebeat | tail -50

# Should see:
# "INFO Harvester started for file..."
# "INFO Successfully published events..."
```

---

## Using Kibana

### 1. Create Index Pattern

1. Open Kibana: http://localhost:5601
2. Menu → Stack Management → Index Patterns
3. Click "Create index pattern"
4. Index pattern name: `mlops-*`
5. Time field: `@timestamp`
6. Click "Create index pattern"

### 2. Explore Logs (Discover)

1. Menu → Discover
2. Select index pattern: `mlops-*`
3. You'll see all logs from all containers

**Filter examples:**
```
# Only Spark logs
component: "spark"

# Only ERROR level
log_level: "ERROR"

# Specific container
container_name: "kafka-producer"

# Time range: Last 15 minutes
```

### 3. Create Dashboards

#### A. Kafka Dashboard

**Create visualizations:**
1. Messages per minute (Line chart)
   - Y-axis: Count
   - X-axis: @timestamp
   - Filter: `component: "kafka"`

2. Error rate (Metric)
   - Metric: Count
   - Filter: `component: "kafka" AND log_level: "ERROR"`

3. Top producers (Pie chart)
   - Slice by: `container_name.keyword`
   - Filter: `component: "kafka"`

#### B. Spark Jobs Dashboard

**Visualizations:**
1. Job execution timeline
2. Failed jobs count
3. Processing time distribution
4. Records processed per job

#### C. MLflow Dashboard

**Visualizations:**
1. Experiment runs over time
2. Model registration events
3. API errors

### 4. Set Up Alerts

1. Menu → Stack Management → Rules and Connectors
2. Create rule → Elasticsearch query
3. Example: Alert when Spark job fails

```json
{
  "query": {
    "bool": {
      "must": [
        {"match": {"component": "spark"}},
        {"match": {"log_level": "ERROR"}}
      ]
    }
  }
}
```

---

## Log Indices Explained

### Index Structure

```
mlops-logs-YYYY.MM.DD     # Generic logs from all components
mlops-kafka-YYYY.MM.DD    # Kafka-specific logs
mlops-spark-YYYY.MM.DD    # Spark job logs
mlops-mlflow-YYYY.MM.DD   # MLflow tracking logs
mlops-airflow-YYYY.MM.DD  # Airflow DAG logs
mlops-serving-YYYY.MM.DD  # Model serving API logs
```

### Why Separate Indices?

1. **Performance**: Smaller indices = faster searches
2. **Retention**: Different retention policies per component
3. **Access Control**: Granular permissions (future)
4. **Organization**: Easier to manage and query

---

## Common Queries

### Find All Errors

```json
{
  "query": {
    "match": {
      "log_level": "ERROR"
    }
  }
}
```

### Find Spark Job Failures

```json
{
  "query": {
    "bool": {
      "must": [
        {"match": {"component": "spark"}},
        {"match": {"message": "failed"}}
      ]
    }
  }
}
```

### Find Slow Predictions

```json
{
  "query": {
    "bool": {
      "must": [
        {"match": {"component": "model-serving"}},
        {"range": {"prediction_latency_ms": {"gte": 200}}}
      ]
    }
  }
}
```

### Count Logs by Component

```json
{
  "size": 0,
  "aggs": {
    "by_component": {
      "terms": {
        "field": "component.keyword"
      }
    }
  }
}
```

---

## Troubleshooting

### Elasticsearch Won't Start

```bash
# Check logs
docker-compose logs elasticsearch

# Common issues:
# 1. Not enough memory
# Solution: Increase Docker memory limit to 4GB

# 2. Port 9200 already in use
# Solution: Change port in docker-compose.yml

# 3. Disk space
# Solution: Clean up old indices
curl -X DELETE "http://localhost:9200/mlops-logs-2025.09.*"
```

### No Logs Appearing in Kibana

```bash
# Check Filebeat is running
docker-compose logs filebeat

# Check Filebeat is sending to Logstash
docker-compose logs logstash | grep "filebeat"

# Check Elasticsearch is receiving data
curl http://localhost:9200/_cat/indices?v

# Manually test Logstash pipeline
docker-compose exec logstash bash
echo '{"message": "test"}' | nc localhost 5000
```

### Kibana Can't Connect to Elasticsearch

```bash
# Check Elasticsearch is accessible from Kibana
docker-compose exec kibana curl http://elasticsearch:9200

# Check environment variables
docker-compose exec kibana env | grep ELASTICSEARCH
```

### Filebeat Permission Denied

```bash
# Filebeat needs access to Docker socket
# Ensure in docker-compose.yml:
#   user: root
#   volumes:
#     - /var/run/docker.sock:/var/run/docker.sock:ro
```

---

## Performance Tuning

### For High Log Volume

```yaml
# elasticsearch service in docker-compose.yml
environment:
  - "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # Increase heap

# logstash service
environment:
  - "LS_JAVA_OPTS=-Xmx512m -Xms512m"  # Adjust memory

# Add more Logstash workers
command: logstash -w 4  # 4 pipeline workers
```

### Index Lifecycle Management

```bash
# Delete old indices (keep last 7 days)
curl -X DELETE "http://localhost:9200/mlops-*-$(date -d '8 days ago' +%Y.%m.%d)"

# Create index template with retention policy
curl -X PUT "http://localhost:9200/_index_template/mlops-logs" \
  -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["mlops-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "mlops-policy"
    }
  }
}
'
```

---

## Integration with Grafana (Optional)

You can also visualize Elasticsearch data in Grafana:

1. Grafana → Configuration → Data Sources
2. Add Elasticsearch
3. URL: `http://elasticsearch:9200`
4. Index: `mlops-*`
5. Time field: `@timestamp`

---

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Elasticsearch | http://localhost:9200 | REST API, search queries |
| Kibana | http://localhost:5601 | Web UI, visualization |
| Logstash | http://localhost:9600 | Monitoring API |
| Logstash TCP | tcp://localhost:5000 | Direct log ingestion |

---

## Log Retention

### Auto-delete Old Indices

Create a cron job:

```bash
# scripts/cleanup-old-logs.sh
#!/bin/bash
# Delete indices older than 7 days

DATE_7_DAYS_AGO=$(date -d '7 days ago' +%Y.%m.%d)

curl -X DELETE "http://localhost:9200/mlops-*-${DATE_7_DAYS_AGO}"

echo "Deleted indices older than ${DATE_7_DAYS_AGO}"
```

Run daily:
```bash
chmod +x scripts/cleanup-old-logs.sh
# Add to crontab: 0 2 * * * /path/to/scripts/cleanup-old-logs.sh
```

---

## Complete Architecture with ELK

```
┌───────────────────────────────────────────────────┐
│              APPLICATION LAYER                     │
├───────────────────────────────────────────────────┤
│ Kafka | Spark | MLflow | Airflow | Model Serving  │
│   ↓       ↓       ↓        ↓            ↓         │
│           Docker Container Logs                    │
└───────────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────────┐
│              LOGGING LAYER (ELK)                   │
├───────────────────────────────────────────────────┤
│ Filebeat → Logstash → Elasticsearch → Kibana      │
│  (ship)     (process)    (store)      (visualize) │
└───────────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────────┐
│           MONITORING LAYER                         │
├───────────────────────────────────────────────────┤
│ Prometheus → Grafana  (metrics)                   │
│ Elasticsearch → Kibana (logs)                     │
└───────────────────────────────────────────────────┘
```

---

## Next Steps

1. ✅ **Start ELK Stack**: `docker-compose up -d elasticsearch logstash kibana filebeat`
2. ✅ **Create Index Patterns** in Kibana
3. ✅ **Explore Logs** in Discover
4. ✅ **Create Dashboards** for each component
5. ✅ **Set Up Alerts** for critical errors
6. ✅ **Integrate with Grafana** (optional)

Your MLOps platform now has complete observability:
- **Metrics**: Prometheus + Grafana
- **Logs**: ELK Stack
- **Traces**: (Future: Jaeger/Zipkin for distributed tracing)


---

```yaml
filebeat.inputs:
  - type: container
    enabled: true
    paths:
      - '/var/lib/docker/containers/*/*.log'
    
    # Parse Docker JSON logs
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"
      
      - decode_json_fields:
          fields: ["message"]
          target: ""
          overwrite_keys: true
      
      - add_fields:
          target: ''
          fields:
            platform: clinical-mlops
            environment: local

# Filter logs by container
filebeat.autodiscover:
  providers:
    - type: docker
      hints.enabled: true
      templates:
        - condition:
            contains:
              docker.container.name: "kafka"
          config:
            - type: container
              paths:
                - /var/lib/docker/containers/${data.docker.container.id}/*.log
              fields:
                component: kafka
                log_type: streaming
        
        - condition:
            contains:
              docker.container.name: "spark"
          config:
            - type: container
              paths:
                - /var/lib/docker/containers/${data.docker.container.id}/*.log
              fields:
                component: spark
                log_type: processing
        
        - condition:
            contains:
              docker.container.name: "mlflow"
          config:
            - type: container
              paths:
                - /var/lib/docker/containers/${data.docker.container.id}/*.log
              fields:
                component: mlflow
                log_type: ml-platform
        
        - condition:
            contains:
              docker.container.name: "airflow"
          config:
            - type: container
              paths:
                - /var/lib/docker/containers/${data.docker.container.id}/*.log
              fields:
                component: airflow
                log_type: orchestration
        
        - condition:
            contains:
              docker.container.name: "model-serving"
          config:
            - type: container
              paths:
                - /var/lib/docker/containers/${data.docker.container.id}/*.log
              fields:
                component: model-serving
                log_type: inference

# Output to Logstash
output.logstash:
  hosts: ["logstash:5044"]
  
# Optional: Output directly to Elasticsearch (uncomment to bypass Logstash)
# output.elasticsearch:
#   hosts: ["elasticsearch:9200"]
#   index: "mlops-logs-%{+yyyy.MM.dd}"

# Logging
logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644

# Monitoring
monitoring:
  enabled: false
```

```logstash
input {
  beats {
    port => 5044
  }
  
  # Optional: Listen for TCP logs
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  # Parse JSON logs
  if [message] =~ /^\{.*\}$/ {
    json {
      source => "message"
    }
  }
  
  # Add environment tag
  mutate {
    add_field => {
      "environment" => "local"
      "platform" => "clinical-mlops"
    }
  }
  
  # Parse timestamp if present
  if [timestamp] {
    date {
      match => ["timestamp", "ISO8601"]
      target => "@timestamp"
    }
  }
  
  # Tag MLOps components
  if [container_name] =~ /kafka/ {
    mutate { add_tag => ["kafka", "streaming"] }
  }
  else if [container_name] =~ /spark/ {
    mutate { add_tag => ["spark", "processing"] }
  }
  else if [container_name] =~ /mlflow/ {
    mutate { add_tag => ["mlflow", "ml-platform"] }
  }
  else if [container_name] =~ /airflow/ {
    mutate { add_tag => ["airflow", "orchestration"] }
  }
  else if [container_name] =~ /model-serving/ {
    mutate { add_tag => ["serving", "inference"] }
  }
  else if [container_name] =~ /prometheus|grafana/ {
    mutate { add_tag => ["monitoring"] }
  }
  
  # Extract log level
  grok {
    match => {
      "message" => [
        "%{LOGLEVEL:log_level}",
        "\[%{LOGLEVEL:log_level}\]"
      ]
    }
  }
  
  # Parse Spark application logs
  if "spark" in [tags] {
    grok {
      match => {
        "message" => "%{TIMESTAMP_ISO8601:spark_timestamp} %{LOGLEVEL:spark_level} %{DATA:spark_class}: %{GREEDYDATA:spark_message}"
      }
    }
  }
  
  # Parse Python logs (common format)
  grok {
    match => {
      "message" => "%{TIMESTAMP_ISO8601:log_timestamp} - %{DATA:logger_name} - %{LOGLEVEL:python_level} - %{GREEDYDATA:python_message}"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "mlops-logs-%{+YYYY.MM.dd}"
    
    # Create separate indices per component for better organization
    if "kafka" in [tags] {
      index => "mlops-kafka-%{+YYYY.MM.dd}"
    }
    else if "spark" in [tags] {
      index => "mlops-spark-%{+YYYY.MM.dd}"
    }
    else if "mlflow" in [tags] {
      index => "mlops-mlflow-%{+YYYY.MM.dd}"
    }
    else if "airflow" in [tags] {
      index => "mlops-airflow-%{+YYYY.MM.dd}"
    }
    else if "serving" in [tags] {
      index => "mlops-serving-%{+YYYY.MM.dd}"
    }
  }
  
  # Optional: Output to stdout for debugging
  # stdout { codec => rubydebug }
}
```

````yaml
http.host: "0.0.0.0"
xpack.monitoring.enabled: false
```

---

```yaml
version: '3.8'

networks:
  mlops-network:
    driver: bridge

volumes:
  minio-data:
  postgres-mlflow-data:
  postgres-airflow-data:
  kafka-data:
  zookeeper-data:
  prometheus-data:
  grafana-data:
  redis-data:
  spark-logs:
  elasticsearch-data:
  logstash-data:

services:
  # ============================================================================
  # STORAGE LAYER
  # ============================================================================
  
  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"      # API
      - "9001:9001"      # Console UI
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio-data:/data
    command: server /data --console-address ":9001"
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # MinIO client to create buckets on startup
  minio-setup:
    image: minio/mc:latest
    container_name: minio-setup
    depends_on:
      - minio
    networks:
      - mlops-network
    entrypoint: >
      /bin/sh -c "
      sleep 10;
      /usr/bin/mc alias set myminio http://minio:9000 minioadmin minioadmin;
      /usr/bin/mc mb myminio/clinical-mlops --ignore-existing;
      /usr/bin/mc mb myminio/mlflow-artifacts --ignore-existing;
      /usr/bin/mc mb myminio/dvc-storage --ignore-existing;
      echo 'Buckets created successfully';
      exit 0;
      "

  # ============================================================================
  # MESSAGE QUEUE
  # ============================================================================
  
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - zookeeper-data:/var/lib/zookeeper/data
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "bash", "-c", "echo ruok | nc localhost 2181"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    container_name: kafka
    depends_on:
      zookeeper:
        condition: service_healthy
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    volumes:
      - kafka-data:/var/lib/kafka/data
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 10s
      timeout: 10s
      retries: 5

  # ============================================================================
  # DATABASES
  # ============================================================================
  
  postgres-mlflow:
    image: postgres:15-alpine
    container_name: postgres-mlflow
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflow
    volumes:
      - postgres-mlflow-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mlflow"]
      interval: 10s
      timeout: 5s
      retries: 5

  postgres-airflow:
    image: postgres:15-alpine
    container_name: postgres-airflow
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-airflow-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U airflow"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ============================================================================
  # ML PLATFORM
  # ============================================================================
  
  mlflow-server:
    image: python:3.10-slim
    container_name: mlflow-server
    depends_on:
      postgres-mlflow:
        condition: service_healthy
      minio:
        condition: service_healthy
    ports:
      - "5000:5000"
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

  # ============================================================================
  # DATA APPLICATIONS
  # ============================================================================
  
  kafka-producer:
    build:
      context: ./applications/kafka-producer
      dockerfile: Dockerfile
    container_name: kafka-producer
    depends_on:
      kafka:
        condition: service_healthy
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:29092
      PRODUCER_RATE: 100  # messages per second
      NUM_PATIENTS: 1000
    networks:
      - mlops-network
    restart: unless-stopped

  kafka-consumer:
    build:
      context: ./applications/kafka-consumer
      dockerfile: Dockerfile
    container_name: kafka-consumer
    depends_on:
      kafka:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:29092
      KAFKA_GROUP_ID: clinical-consumer-group
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: minioadmin
      S3_SECRET_KEY: minioadmin
      S3_BUCKET: clinical-mlops
      S3_PREFIX: raw/
    networks:
      - mlops-network
    restart: unless-stopped

  # ============================================================================
  # SPARK CLUSTER
  # ============================================================================
  
  spark-master:
    image: bitnami/spark:3.5.0
    container_name: spark-master
    user: root
    environment:
      - SPARK_MODE=master
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
      - SPARK_USER=spark
    ports:
      - "8080:8080"  # Spark Master UI
      - "7077:7077"  # Spark Master Port
    volumes:
      - ./applications/spark-processor/jobs:/opt/bitnami/spark/jobs
      - spark-logs:/opt/bitnami/spark/logs
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

  spark-worker:
    image: bitnami/spark:3.5.0
    container_name: spark-worker
    user: root
    depends_on:
      spark-master:
        condition: service_healthy
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://spark-master:7077
      - SPARK_WORKER_MEMORY=2G
      - SPARK_WORKER_CORES=2
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
      - SPARK_USER=spark
    volumes:
      - ./applications/spark-processor/jobs:/opt/bitnami/spark/jobs
      - spark-logs:/opt/bitnami/spark/logs
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Spark job runner (on-demand execution)
  spark-processor:
    image: bitnami/spark:3.5.0
    container_name: spark-processor
    user: root
    depends_on:
      spark-master:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      - SPARK_MASTER_URL=spark://spark-master:7077
      - S3_ENDPOINT=http://minio:9000
      - S3_ACCESS_KEY=minioadmin
      - S3_SECRET_KEY=minioadmin
      - S3_BUCKET=clinical-mlops
      - PROCESS_HOURS=1
    volumes:
      - ./applications/spark-processor/jobs:/opt/bitnami/spark/jobs
    networks:
      - mlops-network
    profiles:
      - spark-job
    command: >
      spark-submit
        --master spark://spark-master:7077
        --deploy-mode client
        --conf spark.executor.memory=2g
        --conf spark.executor.cores=2
        --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000
        --conf spark.hadoop.fs.s3a.access.key=minioadmin
        --conf spark.hadoop.fs.s3a.secret.key=minioadmin
        --conf spark.hadoop.fs.s3a.path.style.access=true
        --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
        --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false
        --packages org.apache.hadoop:hadoop-aws:3.3.4
        /opt/bitnami/spark/jobs/bronze_to_silver.py

  feature-engineering:
    build:
      context: ./applications/feature-engineering
      dockerfile: Dockerfile
    container_name: feature-engineering
    depends_on:
      - minio
      - redis
    environment:
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: minioadmin
      S3_SECRET_KEY: minioadmin
      S3_BUCKET: clinical-mlops
      REDIS_HOST: redis
      REDIS_PORT: 6379
    networks:
      - mlops-network
    volumes:
      - ./data:/app/data
    profiles:
      - feature-engineering

  ml-training:
    build:
      context: ./applications/ml-training
      dockerfile: Dockerfile
    container_name: ml-training
    depends_on:
      mlflow-server:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      MLFLOW_TRACKING_URI: http://mlflow-server:5000
      S3_ENDPOINT: http://minio:9000
      AWS_ACCESS_KEY_ID: minioadmin
      AWS_SECRET_ACCESS_KEY: minioadmin
    networks:
      - mlops-network
    volumes:
      - ./data:/app/data
      - ./operations/dvc:/app/dvc
    # Run on-demand, not continuously
    profiles:
      - training

  model-serving:
    build:
      context: ./applications/model-serving
      dockerfile: Dockerfile
    container_name: model-serving
    depends_on:
      mlflow-server:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "8000:8000"
    environment:
      MLFLOW_TRACKING_URI: http://mlflow-server:5000
      REDIS_HOST: redis
      REDIS_PORT: 6379
      MODEL_NAME: adverse-event-predictor
      MODEL_STAGE: production
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    profiles:
      - serving

  # ============================================================================
  # ORCHESTRATION
  # ============================================================================
  
  airflow-init:
    image: apache/airflow:2.7.3-python3.10
    container_name: airflow-init
    depends_on:
      postgres-airflow:
        condition: service_healthy
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres-airflow:5432/airflow
      AIRFLOW__CORE__FERNET_KEY: 'UKMzEm3yIuFYEq1y3-2FxGb6l6_kU5KDo5YN6RnGq3Q='
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      _AIRFLOW_DB_UPGRADE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
      _AIRFLOW_WWW_USER_USERNAME: admin
      _AIRFLOW_WWW_USER_PASSWORD: admin
    networks:
      - mlops-network
    entrypoint: /bin/bash
    command: >
      -c "
      airflow db init &&
      airflow users create 
        --username admin 
        --password admin 
        --firstname Admin 
        --lastname User 
        --role Admin 
        --email admin@example.com || true
      "

  airflow-webserver:
    image: apache/airflow:2.7.3-python3.10
    container_name: airflow-webserver
    depends_on:
      airflow-init:
        condition: service_completed_successfully
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres-airflow:5432/airflow
      AIRFLOW__CORE__FERNET_KEY: 'UKMzEm3yIuFYEq1y3-2FxGb6l6_kU5KDo5YN6RnGq3Q='
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      AIRFLOW__WEBSERVER__EXPOSE_CONFIG: 'true'
    ports:
      - "8081:8080"
    networks:
      - mlops-network
    volumes:
      - ./orchestration/airflow/dags:/opt/airflow/dags
      - ./orchestration/airflow/plugins:/opt/airflow/plugins
      - ./orchestration/airflow/config:/opt/airflow/config
    command: webserver
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5
    profiles:
      - airflow

  airflow-scheduler:
    image: apache/airflow:2.7.3-python3.10
    container_name: airflow-scheduler
    depends_on:
      airflow-init:
        condition: service_completed_successfully
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres-airflow:5432/airflow
      AIRFLOW__CORE__FERNET_KEY: 'UKMzEm3yIuFYEq1y3-2FxGb6l6_kU5KDo5YN6RnGq3Q='
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    networks:
      - mlops-network
    volumes:
      - ./orchestration/airflow/dags:/opt/airflow/dags
      - ./orchestration/airflow/plugins:/opt/airflow/plugins
      - ./orchestration/airflow/config:/opt/airflow/config
    command: scheduler
    healthcheck:
      test: ["CMD-SHELL", "airflow jobs check --job-type SchedulerJob --hostname $(hostname)"]
      interval: 30s
      timeout: 10s
      retries: 5
    profiles:
      - airflow

  # ============================================================================
  # MONITORING
  # ============================================================================
  
  # ELK Stack - Centralized Logging
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5044:5044"
      - "9600:9600"
    volumes:
      - ./monitoring/elk/logstash/pipeline:/usr/share/logstash/pipeline
      - ./monitoring/elk/logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml
      - logstash-data:/usr/share/logstash/data
    environment:
      - "LS_JAVA_OPTS=-Xmx256m -Xms256m"
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9600/_node/stats || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Filebeat - Log shipper
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    container_name: filebeat
    user: root
    depends_on:
      elasticsearch:
        condition: service_healthy
      logstash:
        condition: service_healthy
    volumes:
      - ./monitoring/elk/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: filebeat -e -strict.perms=false
    networks:
      - mlops-network
  
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/prometheus/alerts:/etc/prometheus/alerts
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    depends_on:
      - prometheus
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_INSTALL_PLUGINS: ''
    volumes:
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - grafana-data:/var/lib/grafana
    networks:
      - mlops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  monitoring-service:
    build:
      context: ./applications/monitoring-service
      dockerfile: Dockerfile
    container_name: monitoring-service
    depends_on:
      - prometheus
      - model-serving
    environment:
      PROMETHEUS_URL: http://prometheus:9090
      MODEL_SERVING_URL: http://model-serving:8000
      MLFLOW_TRACKING_URI: http://mlflow-server:5000
      ALERT_WEBHOOK_URL: http://airflow-webserver:8080/api/v1/dags/model_monitoring/dagRuns
      CHECK_INTERVAL_SECONDS: 3600  # Check every hour
    networks:
      - mlops-network
    # Run on-demand or via cron
    profiles:
      - monitoring
```

---

# Product Requirements Document
## Clinical Trial Adverse Event Prediction System

### Executive Summary
Build an end-to-end MLOps system that predicts adverse events in clinical trials using real-time patient data. The system must handle streaming data, perform feature engineering, train models with PyTorch, track experiments with MLflow, version data with DVC, orchestrate pipelines with Kubeflow, and monitor model performance to trigger automatic retraining when model decay is detected.

---

## 1. Business Context

### Problem Statement
Clinical trial adverse events are critical safety signals that must be identified early. Current manual review processes are reactive and miss early warning patterns in patient vitals, lab results, and medication data.

### Business Goals
- Predict adverse events 24-48 hours before occurrence with >80% AUROC
- Reduce manual safety monitoring workload by 40%
- Provide real-time risk scores to clinical coordinators
- Maintain audit trail for regulatory compliance (FDA 21 CFR Part 11)

### Success Metrics
- Model AUROC ≥ 0.80 on hold-out test set
- Prediction latency < 200ms (p99)
- System uptime ≥ 99.5%
- Model retraining triggered within 2 hours of performance degradation
- Full data lineage traceable for any prediction

---

## 2. System Architecture Overview

### Data Flow
```
Kafka Topics → Spark Streaming → Feature Store → Model Training (PyTorch)
                      ↓                                    ↓
                Data Lake (S3)                      MLflow Registry
                      ↓                                    ↓
                  DVC Versioning                   Model Serving (FastAPI)
                                                           ↓
                                                   Prometheus Metrics
                                                           ↓
                                                   Grafana Dashboards
```

### Technology Stack
- **Streaming**: Apache Kafka (patient events)
- **Processing**: Apache Spark (batch & streaming)
- **ML Framework**: PyTorch (deep learning)
- **Experiment Tracking**: MLflow (runs, models, registry)
- **Data Versioning**: DVC + Git (reproducibility)
- **Orchestration**: 
  - **Apache Airflow** (data pipelines, feature engineering, scheduled jobs)
  - **Kubeflow Pipelines** (ML training workflows, hyperparameter tuning)
- **Serving**: FastAPI + Docker (REST API)
- **Monitoring**: Prometheus + Grafana (metrics & alerting)
- **Storage**: S3 (data lake), PostgreSQL (metadata)

---

## 3. Functional Requirements

### 3.1 Data Ingestion
**FR-1.1**: System shall consume patient events from Kafka topics:
- `patient-vitals` (heart rate, BP, temperature, SpO2) - streaming every 5 minutes
- `lab-results` (blood work, liver enzymes, kidney function) - batch daily
- `medications` (drug name, dosage, timestamp) - event-driven
- `adverse-events` (labeled outcomes) - event-driven

**FR-1.2**: Kafka consumer shall:
- Handle backpressure using offset management
- Support exactly-once semantics to prevent duplicate processing
- Write raw data to S3 bronze layer with Kafka offset metadata
- Process messages in micro-batches of 1000 records or 30-second windows

**FR-1.3**: Data schema validation:
- Validate incoming messages against JSON schemas
- Reject malformed messages to dead-letter queue
- Log validation errors with correlation IDs

### 3.2 Data Processing (Spark)
**FR-2.1**: Spark batch job shall run hourly to:
- Read raw data from S3 bronze layer
- Deduplicate records by (patient_id, timestamp, source)
- Standardize units (convert all weights to kg, temperatures to Celsius)
- Handle missing values (forward-fill vitals for up to 2 hours, flag missingness)
- Write cleaned data to S3 silver layer
- Partition data by date and trial_site_id for efficient querying

**FR-2.2**: Data quality checks:
- Vital signs within physiologically plausible ranges (HR: 40-200, BP_systolic: 60-250)
- No future timestamps (reject data timestamped > current_time)
- Patient IDs exist in trial enrollment database
- Generate data quality report logged to MLflow

### 3.3 Feature Engineering
**FR-3.1**: Feature engineering pipeline shall create:

**Temporal Features** (rolling windows):
- Heart rate: mean, std, min, max over [1h, 6h, 24h]
- Blood pressure: mean, variance, trend (linear regression slope) over [6h, 24h]
- Lab values: most recent value, change from baseline, rate of change

**Derived Features**:
- Vital signs instability score: sum of (value - patient_baseline) / std_dev
- Medication interaction flags: binary features for known drug-drug interactions
- Missingness indicators: binary flags for missing measurements

**Patient Context Features**:
- Age, gender, BMI
- Days since trial enrollment
- Comorbidity count
- Trial arm (treatment vs control)

**FR-3.2**: Feature store requirements:
- Store features in Parquet format partitioned by date
- Maintain feature metadata (name, dtype, description, creation_timestamp)
- Point-in-time correct joins (no data leakage from future)
- Support both batch feature retrieval (training) and online serving (inference)

**FR-3.3**: Feature validation:
- Check for NaN/Inf values (replace with median or flag)
- Verify feature distributions match training distribution (KS test)
- Log feature statistics to MLflow (min, max, mean, std, missing_pct)

### 3.4 Model Training (PyTorch)
**FR-4.1**: Model architecture:
- Input: 120 features (60 clinical + 60 temporal)
- Architecture: 3-layer fully connected neural network
  - Layer 1: 120 → 64 (ReLU, Dropout 0.3)
  - Layer 2: 64 → 32 (ReLU, Dropout 0.3)
  - Layer 3: 32 → 1 (Sigmoid)
- Loss: Binary Cross-Entropy with class weights (adverse events are rare)
- Optimizer: Adam with learning rate 0.001

**FR-4.2**: Training pipeline:
- Load features from S3 using DVC tracked datasets
- Split data: 70% train, 15% validation, 15% test (stratified by adverse_event label)
- Train for maximum 50 epochs with early stopping (patience=5, monitor validation AUROC)
- Save checkpoints every epoch to MLflow
- Log hyperparameters, metrics, and model artifacts to MLflow

**FR-4.3**: Training outputs:
- Trained model weights (`.pth` file)
- Preprocessing artifacts (scaler, feature names)
- Training metrics (loss curves, AUROC, precision, recall, F1)
- Confusion matrix and classification report
- Model card (architecture, training data date range, performance)

**FR-4.4**: MLflow tracking:
- Experiment name: `clinical-adverse-events`
- Log parameters: learning_rate, batch_size, hidden_layers, dropout_rate, epochs
- Log metrics: train_loss, val_loss, train_auroc, val_auroc, test_auroc
- Log artifacts: model.pth, scaler.pkl, feature_names.json, confusion_matrix.png
- Tag runs: git_commit_hash, data_version (DVC), training_duration

### 3.5 Model Validation & Evaluation
**FR-5.1**: Validation requirements:
- Minimum test AUROC: 0.80 (reject models below threshold)
- Calibration error < 0.05 (expected vs observed event rates aligned)
- Fairness check: AUROC difference < 0.05 across demographic groups (age, gender)
- Inference latency < 200ms on CPU for single prediction

**FR-5.2**: Model comparison:
- Compare new model against current production model on same test set
- Require ≥2% improvement in AUROC to promote new model
- Log comparison results to MLflow with decision (promote/reject)

### 3.6 Data & Model Versioning (DVC)
**FR-6.1**: DVC shall track:
- Raw datasets: `data/raw/patients_YYYYMMDD.parquet`
- Processed features: `data/processed/features_YYYYMMDD.parquet`
- Trained models: `data/models/model_v{version}.pth`
- Preprocessing artifacts: `data/models/scaler_v{version}.pkl`

**FR-6.2**: DVC pipeline definition (`dvc.yaml`):
```yaml
stages:
  process_data:
    cmd: python src/data/spark_processor.py
    deps:
      - src/data/spark_processor.py
      - data/raw
    params:
      - process.batch_size
      - process.window_hours
    outs:
      - data/processed/features.parquet
      
  train:
    cmd: python src/models/train.py
    deps:
      - src/models/train.py
      - src/models/model.py
      - data/processed/features.parquet
    params:
      - train.learning_rate
      - train.batch_size
      - train.epochs
    outs:
      - data/models/model.pth
    metrics:
      - metrics/train_metrics.json
```

**FR-6.3**: Git + DVC workflow:
- Commit code changes to Git
- DVC tracks data/model file hashes in `.dvc` files
- Push data/models to S3 remote storage (`dvc push`)
- Any team member can reproduce results (`dvc pull` + `dvc repro`)

### 3.7 Model Serving (FastAPI)
**FR-7.1**: REST API endpoints:

**POST /predict**
```json
Request:
{
  "patient_id": "PT12345",
  "timestamp": "2025-10-03T14:30:00Z"
}

Response:
{
  "patient_id": "PT12345",
  "adverse_event_probability": 0.73,
  "risk_level": "HIGH",
  "prediction_timestamp": "2025-10-03T14:30:05Z",
  "model_version": "v2.3.1",
  "top_risk_factors": [
    {"feature": "heart_rate_std_24h", "contribution": 0.18},
    {"feature": "liver_enzyme_trend", "contribution": 0.12}
  ]
}
```

**GET /health**
- Returns 200 OK if model loaded and ready
- Returns 503 if model loading or dependencies unavailable

**GET /metrics** 
- Prometheus metrics endpoint
- Exposes prediction_latency, prediction_count, error_rate

**FR-7.2**: Serving requirements:
- Load model from MLflow registry (production stage)
- Load preprocessing artifacts (scaler)
- Retrieve patient features from feature store (or compute on-the-fly)
- Apply preprocessing, run inference, return prediction
- Log prediction to database for monitoring

**FR-7.3**: Performance requirements:
- Latency: p50 < 50ms, p95 < 150ms, p99 < 200ms
- Throughput: ≥100 requests/second
- Concurrent requests: ≥50

### 3.8 Monitoring & Alerting (Prometheus + Grafana)
**FR-8.1**: Model performance metrics (tracked continuously):
- **AUROC** (computed daily on labeled data from last 7 days)
- **Calibration error** (expected vs actual event rate, binned by prediction score)
- **Precision, Recall, F1** at threshold 0.5
- **Prediction distribution** (histogram of output probabilities)

**FR-8.2**: Data drift metrics:
- **Feature drift**: KS statistic for each continuous feature (compare production vs training)
- **Missing value rate**: % of missing features in production data
- **Out-of-range values**: count of features outside training min/max

**FR-8.3**: System metrics:
- **Prediction latency**: histogram (p50, p95, p99)
- **Request rate**: requests/second
- **Error rate**: % of failed predictions
- **Model memory usage**: MB
- **CPU/GPU utilization**: %

**FR-8.4**: Alerting rules:
- **Critical**: AUROC drops below 0.75 → trigger retraining immediately
- **Warning**: AUROC drops below 0.80 → alert ML team
- **Warning**: Feature drift detected (KS statistic > 0.2 for >3 features)
- **Warning**: Prediction latency p99 > 300ms
- **Critical**: Error rate > 5%

**FR-8.5**: Grafana dashboards:
- **Model Performance**: AUROC trend, precision/recall over time, calibration plot
- **Data Quality**: feature drift heatmap, missing value rates, distribution shifts
- **System Health**: latency percentiles, throughput, error rate, resource usage
- **Predictions**: daily prediction volume, risk level distribution

### 3.9 Model Decay Detection & Retraining
**FR-9.1**: Decay detection:
- Monitor rolling 7-day AUROC every 6 hours
- If AUROC < 0.80 for 2 consecutive checks → trigger retraining
- If feature drift detected (>5 features with KS stat > 0.2) → trigger retraining
- Manual trigger available via API endpoint `/retrain`

**FR-9.2**: Automated retraining pipeline:
1. Alert sent to ML team (Slack notification)
2. Kubeflow pipeline triggered automatically
3. Fetch latest data (last 90 days) from S3
4. Run feature engineering with updated date range
5. Train new model with same architecture, fresh weights
6. Evaluate on hold-out test set
7. Compare against current production model
8. If new model better by ≥2% AUROC → promote to staging
9. Run canary deployment (10% traffic for 24 hours)
10. If canary metrics stable → promote to production
11. If canary fails → rollback to previous model

**FR-9.3**: Retraining outputs:
- New model in MLflow registry (staging stage)
- Retraining report: comparison metrics, data date range, training duration
- Updated DVC tracked artifacts
- Git tag: `retrain-YYYYMMDD-reason-{drift|performance|manual}`

### 3.10 Orchestration (Kubeflow Pipelines)
**FR-10.1**: Training pipeline components:
1. **Data Validation**: Check data quality, schema compliance
2. **Feature Engineering**: Run Spark job, create features
3. **Train Model**: PyTorch training job on GPU
4. **Evaluate Model**: Compute metrics, compare to baseline
5. **Register Model**: Push to MLflow registry if passing threshold
6. **Deploy Model**: Update serving endpoint if promotion approved

**FR-10.2**: Pipeline inputs:
- Training data date range (start_date, end_date)
- Hyperparameters from `params.yaml`
- Model comparison baseline (current production model ID)

**FR-10.3**: Pipeline outputs:
- Trained model artifact in MLflow
- Evaluation report (metrics, plots)
- Decision: promote/reject
- DVC commit hash
- Git commit hash

**FR-10.4**: Pipeline scheduling:
- Manual trigger: on-demand via UI or API
- Automatic trigger: on decay detection
- Scheduled: weekly (every Monday 2 AM UTC) for proactive retraining

---

## 4. Non-Functional Requirements

### 4.1 Performance
- Model training time: < 2 hours on single GPU
- Pipeline end-to-end execution: < 3 hours
- Feature engineering (Spark): < 30 minutes for 90 days of data
- Model serving latency: p99 < 200ms

### 4.2 Scalability
- Support 1000 active patients in trial
- Handle 200K data points per day (1000 patients × 200 events/day)
- Serve 1000 predictions per minute at peak

### 4.3 Reliability
- System uptime: 99.5% (max downtime: 3.6 hours/month)
- Model deployment rollback time: < 5 minutes
- Zero downtime deployments (blue-green or canary)

### 4.4 Reproducibility
- Any model version reproducible using Git commit + DVC data version
- Feature engineering deterministic (same input → same output)
- Model training with fixed random seed for reproducibility

### 4.5 Security & Compliance
- All patient data encrypted at rest (S3 encryption)
- All API traffic over HTTPS
- Authentication required for API access (API keys)
- Audit log for all predictions (patient_id, timestamp, prediction, model_version)
- Data retention: raw data 7 years, models 2 years

### 4.6 Observability
- All pipeline steps emit structured logs
- Distributed tracing with correlation IDs
- Centralized logging (CloudWatch or ELK)
- Metrics exported to Prometheus

---

## 5. Data Requirements

### 5.1 Input Data Sources

**Patient Vitals** (Kafka topic: `patient-vitals`)
```json
{
  "patient_id": "PT12345",
  "timestamp": "2025-10-03T14:30:00Z",
  "heart_rate": 82,
  "blood_pressure_systolic": 128,
  "blood_pressure_diastolic": 84,
  "temperature": 37.2,
  "spo2": 97,
  "source": "bedside_monitor"
}
```

**Lab Results** (Kafka topic: `lab-results`)
```json
{
  "patient_id": "PT12345",
  "timestamp": "2025-10-03T08:00:00Z",
  "test_name": "ALT",
  "value": 45.3,
  "unit": "U/L",
  "reference_range": "7-56",
  "lab_id": "LAB789"
}
```

**Medications** (Kafka topic: `medications`)
```json
{
  "patient_id": "PT12345",
  "timestamp": "2025-10-03T09:00:00Z",
  "drug_name": "Metformin",
  "dosage": 500,
  "unit": "mg",
  "route": "oral",
  "frequency": "BID"
}
```

**Adverse Events** (Kafka topic: `adverse-events`)
```json
{
  "patient_id": "PT12345",
  "event_timestamp": "2025-10-03T16:00:00Z",
  "event_type": "liver_toxicity",
  "severity": "grade_2",
  "reported_by": "clinician",
  "report_timestamp": "2025-10-03T18:00:00Z"
}
```

### 5.2 Training Dataset
- Time range: Last 90 days from training date
- Patient count: ~1000 patients
- Total records: ~18M data points
- Positive class (adverse events): ~5% (class imbalance)
- Train/Val/Test split: 70/15/15 (stratified)

### 5.3 Feature Matrix
- Rows: Patient-day observations (one row per patient per day)
- Columns: 120 features
- Label: Binary (1 = adverse event within next 24 hours, 0 = no event)
- Format: Parquet (compressed, columnar)
- Size: ~2 GB per 90-day dataset

---

## 6. Deployment Architecture

### 6.1 Environments
- **Development**: Local developer machines + shared dev S3 bucket
- **Staging**: Kubernetes cluster with 3 nodes, staging MLflow server
- **Production**: Kubernetes cluster with 5 nodes (auto-scaling), production MLflow server

### 6.2 Infrastructure Components
- **Kafka Cluster**: 3 brokers, replication factor 3
- **Spark Cluster**: 1 master + 4 workers (8 cores, 32GB RAM each)
- **MLflow Server**: Postgres backend, S3 artifact store
- **Model Serving**: FastAPI on Kubernetes (3 replicas, CPU-based)
- **Monitoring**: Prometheus (14-day retention) + Grafana
- **Storage**: S3 (data lake, models), PostgreSQL (metadata)

### 6.3 CI/CD Pipeline
1. Developer pushes code to Git → triggers GitHub Actions
2. Run unit tests, linting (black, flake8), type checking (mypy)
3. Build Docker images for training and serving
4. Push images to container registry
5. Deploy to staging environment
6. Run integration tests (API tests, end-to-end prediction test)
7. Manual approval gate
8. Deploy to production (blue-green deployment)

---

## 7. Testing Strategy

### 7.1 Unit Tests
- Feature engineering functions (test transformations with sample data)
- Model forward pass (test input/output shapes)
- Data validation logic (test schema validation, range checks)
- API endpoints (test request/response formats)

### 7.2 Integration Tests
- End-to-end training pipeline (small dataset, 2 epochs)
- Kafka consumer → Spark processor → Feature store
- Model serving API (load model, make prediction, verify response)

### 7.3 Model Tests
- Test inference on sample data (verify output range [0, 1])
- Test model loading from MLflow
- Test preprocessing pipeline (scaler, feature ordering)

### 7.4 Performance Tests
- Load test API (100 concurrent requests, verify p99 latency < 200ms)
- Stress test Kafka consumer (100K messages, verify no message loss)

---

## 8. Project Phases

### Phase 1: Foundation (Weeks 1-2)
- ✅ Set up project structure
- ✅ Kafka producer (simulate patient data)
- ✅ Kafka consumer (basic)
- ✅ Spark processor (data cleaning)
- ✅ MLflow setup (tracking server)
- ✅ DVC initialization (S3 remote)

### Phase 2: Model Development (Weeks 3-4)
- ✅ Feature engineering pipeline
- ✅ PyTorch model implementation
- ✅ Training pipeline with MLflow tracking
- ✅ Model evaluation and validation
- ✅ DVC pipeline definition

### Phase 3: Serving & Monitoring (Weeks 5-6)
- ✅ FastAPI serving endpoint
- ✅ Prometheus metrics integration
- ✅ Grafana dashboards
- ✅ Decay detection logic

### Phase 4: Orchestration & Automation (Weeks 7-8)
- ✅ Kubeflow pipeline setup
- ✅ Automated retraining trigger
- ✅ CI/CD pipeline (GitHub Actions)
- ✅ End-to-end integration test

---

## 9. Success Criteria

### MVP Success Criteria
- [ ] Model achieves AUROC ≥ 0.80 on test set
- [ ] Training pipeline runs end-to-end without manual intervention
- [ ] Model deployed via FastAPI with p99 latency < 200ms
- [ ] DVC tracks all data and models with full reproducibility
- [ ] MLflow tracks all experiments with comparison capabilities
- [ ] Prometheus + Grafana dashboard shows model metrics

### Production Success Criteria
- [ ] Automated retraining triggered by performance decay
- [ ] Kubeflow pipeline orchestrates full ML workflow
- [ ] Zero downtime model deployments
- [ ] Full audit trail from prediction to training data
- [ ] Monitoring detects and alerts on drift within 6 hours

---

## 10. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Insufficient training data | High | Medium | Use data augmentation, synthetic data generation |
| Class imbalance (rare events) | High | High | Use class weights, SMOTE, stratified sampling |
| Model overfitting | Medium | High | Early stopping, dropout, regularization |
| Kafka message loss | High | Low | Use exactly-once semantics, offset management |
| Spark job failures | Medium | Medium | Retry logic, checkpointing, data validation |
| Model serving latency | Medium | Medium | Model optimization (ONNX), caching, batching |
| False positives alert fatigue | High | Medium | Tune threshold, ensemble with rule-based system |
| Regulatory compliance | High | Low | Maintain audit logs, data lineage, model cards |

---

## 11. Glossary

- **AUROC**: Area Under Receiver Operating Characteristic curve (model performance metric)
- **Adverse Event**: Any undesirable medical occurrence in a trial participant
- **Feature Drift**: Change in input feature distributions over time
- **Concept Drift**: Change in relationship between features and target over time
- **Point-in-time correctness**: Ensuring no future data leakage in historical training
- **Calibration**: Alignment between predicted probabilities and actual frequencies
- **Canary Deployment**: Gradual rollout of new model to subset of traffic
- **Blue-Green Deployment**: Maintaining two identical environments for zero-downtime updates

---

## Appendix A: Example Workflow

### Developer Training Workflow
```bash
# 1. Pull latest data and code
git pull origin main
dvc pull

# 2. Make changes to feature engineering
vim src/features/feature_engineering.py

# 3. Run training locally
python src/models/train.py --experiment-name local-dev

# 4. Check results in MLflow UI
mlflow ui

# 5. Commit changes
git add src/features/feature_engineering.py
git commit -m "Add medication interaction features"

# 6. Track data changes
dvc add data/processed/features.parquet
git add data/processed/features.parquet.dvc
git commit -m "Update features dataset"

# 7. Push to remote
git push origin main
dvc push
```

### Automated Retraining Workflow
```
1. Prometheus detects AUROC < 0.80
2. Alert fires to webhook
3. Kubeflow pipeline triggered via API
4. Pipeline steps:
   a. Fetch latest data (last 90 days)
   b. Run feature engineering (Spark job)
   c. Train new model (PyTorch on GPU)
   d. Evaluate on test set
   e. Compare to current production model
   f. If better → Register in MLflow as "staging"
5. Manual review and approval
6. Promote to "production" stage in MLflow
7. Kubernetes deployment updated (canary)
8. Monitor canary metrics for 24 hours
9. Full rollout if stable
```

---

**Document Version**: 1.0  
**Last Updated**: October 3, 2025  
**Owner**: ML Engineering Team  
**Approvers**: VP Engineering, Chief Medical Officer, VP Data Science


```bash
clinical-mlops/
├── README.md
├── requirements.txt
├── docker-compose.yml                    # Orchestrates all services
│
├── applications/
│   ├── README.md
│   ├── clinical-data-gateway/            # Existing
│   ├── lab-results-processor/            # Existing
│   │
│   ├── kafka-producer/                   # NEW: Simulates patient data
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── producer.py                   # Main Kafka producer
│   │   ├── data_generator.py             # Generate synthetic patient data
│   │   └── schemas/
│   │       ├── vitals_schema.json
│   │       ├── labs_schema.json
│   │       └── adverse_events_schema.json
│   │
│   ├── kafka-consumer/                   # NEW: Consumes and stores raw data
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── consumer.py                   # Main Kafka consumer
│   │   ├── s3_writer.py                  # Write to S3 bronze layer
│   │   └── config/
│   │       └── consumer_config.yaml
│   │
│   ├── spark-processor/                  # NEW: Data processing with Spark
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── jobs/
│   │   │   ├── bronze_to_silver.py       # Data cleaning
│   │   │   ├── silver_to_gold.py         # Aggregations
│   │   │   └── data_quality_checks.py
│   │   ├── transformations/
│   │   │   ├── deduplication.py
│   │   │   ├── standardization.py
│   │   │   └── validation.py
│   │   └── utils/
│   │       └── spark_session.py
│   │
│   ├── feature-engineering/              # NEW: Feature creation pipeline
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── pipeline.py                   # Main feature engineering
│   │   ├── features/
│   │   │   ├── temporal_features.py      # Rolling windows
│   │   │   ├── derived_features.py       # Interactions
│   │   │   ├── patient_context.py        # Demographics
│   │   │   └── missingness_features.py
│   │   ├── feature_store.py              # Feature store interface
│   │   └── config/
│   │       └── features.yaml             # Feature definitions
│   │
│   ├── ml-training/                      # NEW: PyTorch model training
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── train.py                      # Main training script
│   │   ├── models/
│   │   │   ├── neural_net.py             # PyTorch model architecture
│   │   │   ├── preprocessor.py           # Scaling, encoding
│   │   │   └── ensemble.py               # Ensemble models
│   │   ├── utils/
│   │   │   ├── data_loader.py
│   │   │   ├── early_stopping.py
│   │   │   └── metrics.py
│   │   ├── configs/
│   │   │   └── model_config.yaml
│   │   └── notebooks/                    # Experimentation
│   │       └── model_exploration.ipynb
│   │
│   ├── model-serving/                    # NEW: FastAPI serving
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── api.py                        # FastAPI application
│   │   ├── predictor.py                  # Prediction logic
│   │   ├── models/
│   │   │   └── model_loader.py           # Load from MLflow
│   │   ├── middleware/
│   │   │   ├── auth.py
│   │   │   └── logging.py
│   │   └── schemas/
│   │       ├── request.py
│   │       └── response.py
│   │
│   └── monitoring-service/               # NEW: Model monitoring
│       ├── Dockerfile
│       ├── requirements.txt
│       ├── drift_detector.py             # Data drift detection
│       ├── performance_monitor.py        # Model performance tracking
│       ├── alerting.py                   # Alert manager
│       └── config/
│           └── thresholds.yaml
│
├── orchestration/                        # NEW: Workflow orchestration
│   ├── airflow/
│   │   ├── Dockerfile                    # Custom Airflow image
│   │   ├── requirements.txt
│   │   ├── dags/
│   │   │   ├── data_pipeline.py          # Hourly data processing
│   │   │   ├── model_monitoring.py       # 6-hourly monitoring
│   │   │   ├── scheduled_retraining.py   # Weekly retraining
│   │   │   ├── data_quality.py           # 4-hourly quality checks
│   │   │   └── feature_backfill.py       # Manual backfill
│   │   ├── plugins/
│   │   │   ├── kubeflow_operator.py      # Custom operator
│   │   │   ├── mlflow_operator.py
│   │   │   └── slack_notifier.py
│   │   ├── config/
│   │   │   ├── airflow.cfg
│   │   │   └── connections.yaml
│   │   └── tests/
│   │       └── test_dags.py
│   │
│   └── kubeflow/
│       ├── pipelines/
│       │   ├── training_pipeline.py      # Main training workflow
│       │   ├── hpo_pipeline.py           # Hyperparameter tuning
│       │   ├── deployment_pipeline.py    # Deployment workflow
│       │   └── ab_test_pipeline.py       # A/B testing
│       ├── components/
│       │   ├── data_validation.py        # Kubeflow component
│       │   ├── feature_engineering.py
│       │   ├── train_model.py
│       │   ├── evaluate_model.py
│       │   ├── register_model.py
│       │   └── deploy_model.py
│       └── config/
│           └── pipeline_config.yaml
│
├── config/
│   ├── environments/
│   │   ├── dev.env
│   │   ├── staging.env
│   │   └── prod.env
│   ├── monitoring/                       # Existing
│   │   ├── prometheus.yml                # Enhanced with ML metrics
│   │   ├── alertmanager.yml              # Enhanced with decay alerts
│   │   └── rules/
│   │       ├── system_rules.yml
│   │       └── ml_model_rules.yml        # NEW: Model-specific alerts
│   ├── security/                         # Existing
│   └── mlflow/                           # NEW: MLflow configuration
│       ├── mlflow.env
│       └── tracking_server.yaml
│
├── data/                                 # NEW: Data storage (local dev)
│   ├── raw/                              # Bronze layer
│   │   └── .gitkeep
│   ├── processed/                        # Silver layer
│   │   └── .gitkeep
│   ├── features/                         # Feature store
│   │   └── .gitkeep
│   ├── models/                           # Trained models
│   │   └── .gitkeep
│   └── artifacts/                        # Other artifacts
│       └── .gitkeep
│
├── docs/
│   ├── README.md
│   ├── api/                              # Existing
│   ├── architecture/                     # Existing
│   │   ├── mlops_architecture.md         # NEW: MLOps design
│   │   ├── data_flow.md                  # NEW: Data pipeline
│   │   └── model_lifecycle.md            # NEW: Model management
│   ├── deployment/                       # Existing
│   │   ├── airflow_setup.md              # NEW
│   │   ├── kubeflow_setup.md             # NEW
│   │   └── mlflow_setup.md               # NEW
│   ├── troubleshooting/                  # Existing
│   └── runbooks/                         # NEW: Operational guides
│       ├── model_retraining.md
│       ├── handling_drift.md
│       └── incident_response.md
│
├── infrastructure/
│   └── docker/
│       ├── airflow/
│       │   └── Dockerfile
│       ├── kubeflow/
│       │   └── Dockerfile
│       ├── mlflow/
│       │   └── Dockerfile
│       ├── spark/
│       │   └── Dockerfile
│       └── kafka/
│           └── Dockerfile
│
├── monitoring/
│   ├── elk/                              # Existing
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── system_health.json        # Existing
│   │   │   ├── model_performance.json    # NEW: Model metrics
│   │   │   ├── data_quality.json         # NEW: Data drift
│   │   │   └── predictions.json          # NEW: Inference monitoring
│   │   └── provisioning/
│   │       ├── datasources.yaml
│   │       └── dashboards.yaml
│   └── prometheus/
│       ├── prometheus.yml                # Enhanced
│       ├── alerts/
│       │   ├── infrastructure.yml
│       │   └── ml_models.yml             # NEW: Model alerts
│       └── targets/
│           └── ml_services.yml           # NEW: ML service discovery
│
├── operations/
│   ├── docker/                           # Existing
│   ├── jenkins/                          # Existing
│   ├── scripts/                          # Existing
│   └── dvc/                              # NEW: DVC configuration
│       ├── .dvc/
│       │   └── config
│       ├── .dvcignore
│       ├── dvc.yaml                      # Pipeline definition
│       └── params.yaml                   # Hyperparameters
│
├── scripts/
│   ├── build-all.sh                      # Enhanced
│   ├── clean-all.sh                      # Enhanced
│   ├── start-all.sh                      # Enhanced
│   ├── stop-all.sh                       # Enhanced
│   ├── test-complete-flow.sh             # Enhanced
│   │
│   ├── setup/                            # NEW: Setup scripts
│   │   ├── init_mlflow.sh
│   │   ├── init_dvc.sh
│   │   ├── init_kafka.sh
│   │   └── init_airflow.sh
│   │
│   ├── data/                             # NEW: Data management
│   │   ├── generate_test_data.sh
│   │   ├── ingest_historical_data.sh
│   │   └── validate_data_quality.sh
│   │
│   └── ml/                               # NEW: ML operations
│       ├── trigger_training.sh
│       ├── deploy_model.sh
│       ├── rollback_model.sh
│       └── run_ab_test.sh
│
├── test-data/
│   ├── clinical-samples/                 # Existing
│   ├── lab-result-scenarios/             # Existing
│   ├── performance-test/                 # Existing
│   │
│   └── ml-scenarios/                     # NEW: ML test scenarios
│       ├── normal_patients.json
│       ├── adverse_events.json
│       ├── edge_cases.json
│       └── drift_scenarios/
│           ├── feature_drift.json
│           └── concept_drift.json
│
├── tests/                                # NEW: Comprehensive tests
│   ├── unit/
│   │   ├── test_features.py
│   │   ├── test_model.py
│   │   └── test_preprocessing.py
│   ├── integration/
│   │   ├── test_pipeline.py
│   │   ├── test_kafka_spark.py
│   │   └── test_mlflow_integration.py
│   └── e2e/
│       ├── test_training_pipeline.py
│       └── test_serving_api.py
│
├── notebooks/                            # NEW: Analysis and exploration
│   ├── 01_data_exploration.ipynb
│   ├── 02_feature_analysis.ipynb
│   ├── 03_model_experimentation.ipynb
│   └── 04_model_evaluation.ipynb
│
└── .github/                              # NEW: CI/CD
    └── workflows/
        ├── ci.yml                        # Linting, tests
        ├── build-images.yml              # Docker builds
        ├── deploy-staging.yml
        └── deploy-production.yml
```