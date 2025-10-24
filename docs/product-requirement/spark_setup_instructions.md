# Spark Processor Setup & Testing

## Quick Setup (3 Steps)

### 1. Create Directory Structure

```bash
# Create Spark processor directories
mkdir -p applications/spark-processor/jobs
mkdir -p monitoring/prometheus/alerts
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/dashboards
```

### 2. Place Files

**Spark Processor** (`applications/spark-processor/`):
- `jobs/bronze_to_silver.py` - Main Spark job
- `Dockerfile` - Spark container with dependencies

**Prometheus** (`monitoring/prometheus/`):
- `prometheus.yml` - Main configuration
- `alerts/ml_model_rules.yml` - Alert rules

**Grafana** (`monitoring/grafana/`):
- `provisioning/datasources/datasources.yaml` - Prometheus datasource
- `provisioning/dashboards/dashboards.yaml` - Dashboard config
- `dashboards/data-pipeline.json` - Data pipeline dashboard

**Scripts** (`scripts/`):
- `run-spark-job.sh` - Run Spark job manually
- `test-spark-pipeline.sh` - End-to-end pipeline test

### 3. Start Services & Test

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Start Spark cluster
docker-compose up -d spark-master spark-worker

# Wait for Spark to be ready (30 seconds)
sleep 30

# Test the complete pipeline
./scripts/test-spark-pipeline.sh
```

## What the Test Does

The test script validates the entire data flow:

```
1. Kafka Producer → Generating data ✓
2. Kafka Consumer → Writing to MinIO bronze ✓
3. Spark Processor → Reading bronze, writing silver ✓
4. Verification → Confirming parquet files exist ✓
```

## Manual Spark Job Execution

```bash
# Process last 1 hour of data (default)
./scripts/run-spark-job.sh

# Process last 6 hours
./scripts/run-spark-job.sh 6

# Process last 24 hours
./scripts/run-spark-job.sh 24
```

## Verify Data Processing

### 1. Check Spark UI
- Open: http://localhost:8080
- View running/completed jobs
- Check worker status

### 2. View Processed Data in MinIO
1. Open: http://localhost:9001
2. Login: minioadmin / minioadmin
3. Navigate: `clinical-mlops` → `processed/`
4. You should see:
   ```
   processed/
   ├── patient-vitals/
   │   └── date=2025-10-05/
   │       └── part-*.parquet
   ├── lab-results/
   ├── medications/
   └── adverse-events/
   ```

### 3. Inspect Parquet Files

```bash
# Install pyarrow locally to read parquet
pip install pyarrow pandas

# Download and read a file
python << EOF
import boto3
import pandas as pd
from io import BytesIO

s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin'
)

# List files
response = s3.list_objects_v2(
    Bucket='clinical-mlops',
    Prefix='processed/patient-vitals/date='
)

if response.get('Contents'):
    # Get first parquet file
    key = response['Contents'][0]['Key']
    print(f"Reading: {key}")
    
    obj = s3.get_object(Bucket='clinical-mlops', Key=key)
    df = pd.read_parquet(BytesIO(obj['Body'].read()))
    
    print(f"\nShape: {df.shape}")
    print(f"\nColumns: {df.columns.tolist()}")
    print(f"\nSample data:")
    print(df.head())
    print(f"\nData types:")
    print(df.dtypes)
EOF
```

## Monitoring with Prometheus + Grafana

### 1. Start Monitoring Services

```bash
docker-compose up -d prometheus grafana
```

### 2. Access Grafana
1. Open: http://localhost:3000
2. Login: admin / admin
3. Navigate to: Dashboards → Clinical MLOps - Data Pipeline
4. You'll see:
   - Data processing rate
   - Data quality score
   - Invalid records rate
   - Spark job duration
   - Duplicates removed
   - Kafka consumer lag

### 3. View Prometheus Metrics
1. Open: http://localhost:9090
2. Try these queries:
   ```promql
   # Data processing rate
   rate(data_records_processed_total[5m])
   
   # Data quality score
   data_quality_score
   
   # Invalid records rate
   rate(data_invalid_records_total[5m])
   
   # Spark job duration
   spark_job_duration_seconds
   ```

### 4. Check Alerts
1. In Prometheus: http://localhost:9090/alerts
2. You'll see rules for:
   - High invalid record rate
   - Data quality degradation
   - Spark job failures

## Data Flow Verification

### Bronze Layer (Raw JSON)
```bash
# View raw data structure
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc cat myminio/clinical-mlops/raw/patient-vitals/date=2025-10-05/hour=14/batch_*.json | head -5
```

Expected format:
```json
{"patient_id":"PT00123","timestamp":"2025-10-05T14:30:00Z","heart_rate":82.3,...}
{"patient_id":"PT00456","timestamp":"2025-10-05T14:30:05Z","heart_rate":75.1,...}
```

### Silver Layer (Parquet)
```bash
# List processed files
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls --recursive myminio/clinical-mlops/processed/patient-vitals/
```

Expected structure:
```
processed/patient-vitals/
└── date=2025-10-05/
    ├── part-00000-*.parquet
    ├── part-00001-*.parquet
    └── _SUCCESS
```

## Spark Job Metrics

After running the Spark job, you'll see metrics like:

```
==================================================
PROCESSING METRICS
==================================================
records_read: 15234
records_written: 14891
duplicates_removed: 298
invalid_records: 45
out_of_range_values: 0
==================================================
Data Quality: 97.75%
==================================================
```

## What Gets Cleaned?

### 1. Deduplication
- Removes duplicate records by (patient_id, timestamp, source)
- Keeps most recent record

### 2. Validation
- **Vitals**: Filters physiologically impossible values
  - Heart rate: 40-200 bpm
  - BP systolic: 60-250 mmHg
  - BP diastolic: 40-150 mmHg
  - Temperature: 35-42°C
  - SpO2: 70-100%

- **Labs**: Filters negative values, missing test names

- **Medications**: Filters negative dosages, missing drug names

- **Adverse Events**: Validates severity grades

### 3. Enrichment
- Adds processing timestamp
- Adds data quality score
- Calculates derived metrics:
  - Pulse pressure = systolic - diastolic
  - Mean arterial pressure = (systolic + 2*diastolic) / 3

### 4. Standardization
- Uppercase drug names
- Consistent date formats
- Severity scores (grade_1 = 1, grade_2 = 2, etc.)

## Troubleshooting

### Spark Job Fails

```bash
# Check Spark master logs
docker-compose logs spark-master

# Check Spark worker logs
docker-compose logs spark-worker

# Verify S3 connectivity from Spark
docker-compose exec spark-master bash -c "
curl http://minio:9000/minio/health/live
"
```

### No Data in Silver Layer

```bash
# Check if bronze layer has data
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls --recursive myminio/clinical-mlops/raw/

# Check Spark job logs for errors
docker-compose logs spark-master | grep ERROR

# Verify time range - may need to adjust PROCESS_HOURS
docker-compose exec spark-master \
  spark-submit --conf spark.env.PROCESS_HOURS=24 ...
```

### Prometheus Not Scraping Metrics

```bash
# Check Prometheus targets
# Open: http://localhost:9090/targets

# Verify services are exposing metrics
curl http://localhost:8000/metrics  # If metrics exporter running
```

## Next Steps

Now that you have clean data in the silver layer, you can:

### 1. Feature Engineering
- Create rolling window features (1h, 6h, 24h)
- Calculate patient baselines
- Generate interaction features
- Store in feature store

### 2. Model Training
- Load silver layer data
- Train PyTorch model
- Track with MLflow
- Version with DVC

### 3. Automation
- Schedule Spark job with Airflow
- Run hourly to keep silver layer fresh
- Trigger feature engineering after Spark completes

## Architecture Status

✅ **Complete Data Pipeline**:
```
Kafka Producer → Kafka Topics → Kafka Consumer → MinIO Bronze
                                                        ↓
                                                  Spark Processor
                                                        ↓
                                                  MinIO Silver
                                                        ↓
                                          [Ready for Feature Engineering]
```

✅ **Monitoring**:
```
Spark Metrics → Prometheus → Grafana Dashboards
                    ↓
                 Alerts
```

## Performance Benchmarks

**Expected Processing Times** (1000 patients, 1 hour of data):
- Bronze layer: ~500 KB - 1 MB per batch
- Silver layer: ~200-400 KB (Parquet compression)
- Spark job duration: 10-30 seconds
- Data quality: 95-99% (3-5% filtered as invalid/duplicates)

Monitor these in Grafana!
