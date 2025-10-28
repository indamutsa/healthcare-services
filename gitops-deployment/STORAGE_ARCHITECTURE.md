# Storage Architecture: Hybrid PVC + MinIO S3

## Overview

The Clinical MLOps Platform uses a **hybrid storage architecture** that mirrors production cloud environments:

- **Block Storage (PVCs)**: For databases requiring ACID guarantees and low-latency access
- **Object Storage (MinIO/S3)**: For large files, artifacts, logs, and distributed data

This approach provides:
- ✅ **Cost efficiency**: Object storage is cheaper for large, infrequently accessed data
- ✅ **Scalability**: Unlimited storage without provisioning volumes
- ✅ **Durability**: Built-in replication and versioning
- ✅ **Cloud-native**: Easy migration to AWS S3, Azure Blob, or GCP Cloud Storage

---

## Storage Strategy

### 🔵 **Block Storage (PVCs)** - Keep on Fast Disks

Used for services requiring:
- Low latency (<1ms)
- High IOPS
- ACID transactions
- Sequential write performance

**Services**:
| Service | Storage Type | Size | Purpose |
|---------|-------------|------|---------|
| **PostgreSQL (MLflow)** | PVC | 10Gi | Experiment metadata, model registry |
| **PostgreSQL (Airflow)** | PVC | 10Gi | DAG state, task instances |
| **Redis** | PVC | 5Gi | Online features, prediction cache |
| **Kafka** | PVC | 20Gi | Message queue, event streaming |
| **Zookeeper** | PVC | 5Gi | Kafka coordination |

**Total PVC Storage**: ~50Gi

---

### 🟢 **Object Storage (MinIO/S3)** - Use for Everything Else

Used for:
- Large files (>1MB)
- Write-once, read-many patterns
- Archival and long-term retention
- Distributed access
- Versioning and immutability

**Services & Data**:
| Data Type | MinIO Bucket | Purpose | Retention |
|-----------|--------------|---------|-----------|
| **MLflow Artifacts** | `mlflow-artifacts` | Model files, plots, metrics | Indefinite |
| **Model Artifacts** | `model-artifacts` | Production models, versions | 90 days |
| **Airflow Logs** | `airflow-logs` | Task execution logs | 30 days |
| **Feature Store** | `feature-store` | Offline features (parquet) | 30 days |
| **Training Data** | `training-data` | Historical datasets | 90 days |
| **Backups** | `backups` | PostgreSQL dumps, volume snapshots | 30 days |
| **Kubernetes Volumes** | `kubernetes-volumes` | CSI-provisioned volumes | Varies |

**Total S3 Storage**: Unlimited (auto-scaling)

---

## Implementation Details

### MinIO Configuration

MinIO runs as a Kubernetes service providing S3-compatible object storage:

```yaml
# MinIO Service
Service: minio.clinical-mlops.svc.cluster.local:9000
Console: minio.clinical-mlops.svc.cluster.local:9001
Credentials: Stored in minio-credentials Secret
```

**Buckets Created**:
```bash
mc ls myminio/
[2025-01-28] mlflow-artifacts/
[2025-01-28] model-artifacts/
[2025-01-28] airflow-logs/
[2025-01-28] feature-store/
[2025-01-28] training-data/
[2025-01-28] backups/
[2025-01-28] kubernetes-volumes/
```

---

### Service-Specific Integrations

#### 1. **MLflow** - S3 Artifact Storage

**Configuration**:
```yaml
env:
- name: MLFLOW_S3_ENDPOINT_URL
  value: "http://minio:9000"
- name: MLFLOW_DEFAULT_ARTIFACT_ROOT
  value: "s3://mlflow-artifacts/"
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: minio-credentials
      key: accessKey
```

**Storage Flow**:
```
Experiment Logged → PostgreSQL (metadata)
                  ↓
Model Artifacts → MinIO s3://mlflow-artifacts/
```

**Benefits**:
- Unlimited artifact storage
- No PVC size constraints
- Automatic versioning
- Easy sharing across experiments

---

#### 2. **Airflow** - S3 Remote Logging

**Configuration**:
```yaml
env:
- name: AIRFLOW__LOGGING__REMOTE_LOGGING
  value: "True"
- name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
  value: "s3://airflow-logs"
```

**Storage Flow**:
```
Task Execution → Logs written locally
              ↓
              Upload to MinIO s3://airflow-logs/
              ↓
              Delete local logs (retention: 7 days)
```

**Benefits**:
- Long-term log retention (30 days)
- No log volume growth on pods
- Centralized log storage
- Query logs from any webserver replica

---

#### 3. **Feature Store** - S3 Feature Storage

**Configuration**:
```yaml
env:
- name: FEATURE_STORE_TYPE
  value: "s3"
- name: FEATURE_STORE_S3_BUCKET
  value: "feature-store"
- name: OFFLINE_STORE_PATH
  value: "s3://feature-store/offline/"
```

**Storage Flow**:
```
Feature Engineering Job → Parquet files → s3://feature-store/offline/
                                       ↓
                                       Online Features → Redis (cache)
```

**Benefits**:
- Scalable parquet storage
- Point-in-time feature retrieval
- Easy feature sharing across teams
- Columnar storage efficiency

---

#### 4. **Model Serving** - S3 Model Loading

**Configuration**:
```yaml
initContainers:
- name: download-model
  image: minio/mc:latest
  command:
  - mc mirror minio/model-artifacts/production/latest /models/
```

**Storage Flow**:
```
Training → Model Saved → s3://model-artifacts/production/v1.2.3
                       ↓
Pod Starts → Download from S3 → /models/ (emptyDir)
          ↓
          Model Loaded in Memory
```

**Benefits**:
- No PVC needed per pod
- Fast pod startup with cached downloads
- Easy model rollback (change S3 path)
- Automatic model updates (CronJob sync)

---

## Storage Class (Optional CSI Driver)

For advanced use cases, you can use the **S3 CSI Driver** to mount MinIO buckets as Kubernetes volumes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-s3
provisioner: ru.yandex.s3.csi
parameters:
  bucket: kubernetes-volumes
  mounter: geesefs
```

**Use Cases**:
- Legacy applications expecting file systems
- High-throughput read operations
- Shared volumes across multiple pods

**Note**: For most use cases, **direct S3 API integration is preferred** over CSI mounts for performance and simplicity.

---

## Cost Comparison

### Scenario: 500GB of Data

#### Option 1: All PVCs (Traditional)
```
500GB PVC × $0.10/GB/month = $50/month
+ Provisioning overhead
+ Manual scaling
```

#### Option 2: Hybrid (Our Approach)
```
50GB PVCs (databases) × $0.10/GB = $5/month
450GB S3 (artifacts) × $0.023/GB = $10.35/month
Total: $15.35/month (70% cost savings)
```

---

## Migration from Docker Compose

### Before (Docker Compose)
```yaml
volumes:
  mlflow-artifacts:
  airflow-logs:
  feature-data:
  model-cache:
```

### After (Kubernetes + MinIO)
```yaml
# No volumes needed - all in S3
env:
- MLFLOW_S3_ENDPOINT_URL: http://minio:9000
- AIRFLOW_REMOTE_LOGGING: s3://airflow-logs
- FEATURE_STORE_PATH: s3://feature-store
- MODEL_BUCKET: s3://model-artifacts
```

---

## Disaster Recovery

### Backup Strategy

**PVC Backups** (Velero):
```bash
# Automated daily snapshots
velero schedule create daily-pvc \
  --schedule="0 2 * * *" \
  --include-namespaces=clinical-mlops \
  --snapshot-volumes
```

**S3 Backups** (MinIO Replication):
```yaml
# Mirror to offsite S3
mc mirror minio/mlflow-artifacts s3://backup-bucket/mlflow-artifacts/
mc mirror minio/model-artifacts s3://backup-bucket/model-artifacts/
```

### Restore Procedures

**PVC Restore**:
```bash
velero restore create --from-backup daily-pvc-20250128
```

**S3 Restore**:
```bash
mc mirror s3://backup-bucket/mlflow-artifacts/ minio/mlflow-artifacts/
```

---

## Performance Tuning

### MLflow Artifact Storage
- ✅ Use multipart uploads for large files (>5MB)
- ✅ Enable client-side caching
- ✅ Parallelize downloads

### Airflow Remote Logging
- ✅ Batch log uploads (every 5 minutes)
- ✅ Compress logs before upload (gzip)
- ✅ Use lifecycle policies for old logs

### Feature Store
- ✅ Partition parquet by date
- ✅ Use columnar compression (snappy)
- ✅ Cache frequently accessed features in Redis

---

## Monitoring

### S3 Metrics (Prometheus)
```yaml
# MinIO exports metrics at /minio/v2/metrics/cluster
- minio_s3_requests_total
- minio_s3_traffic_sent_bytes
- minio_bucket_usage_total_bytes
```

### Storage Dashboards
- **MinIO Dashboard**: Storage usage, request rates, errors
- **PVC Dashboard**: Volume usage, IOPS, latency
- **Cost Dashboard**: Storage costs by type

---

## Security

### Access Control
- **MinIO**: Bucket policies with least-privilege access
- **PVCs**: RBAC permissions, pod security policies

### Encryption
- **At Rest**: MinIO encryption (AES-256)
- **In Transit**: TLS for S3 API calls

### Compliance (HIPAA)
- Audit logging enabled for all S3 operations
- Immutable backups (WORM mode)
- Access logs retained for 7 years

---

## Best Practices

### ✅ DO
- Use S3 for large files (>1MB)
- Use PVCs for databases
- Enable versioning on critical buckets
- Set lifecycle policies for old data
- Monitor storage costs

### ❌ DON'T
- Store small files (<100KB) in S3 (high overhead)
- Use S3 for high-frequency writes (use Redis/Kafka)
- Mount S3 as filesystem unless necessary
- Store secrets in S3 without encryption

---

## Quick Reference

### MinIO CLI Commands
```bash
# List buckets
mc ls myminio/

# Copy file to S3
mc cp model.pkl myminio/model-artifacts/

# Mirror directory
mc mirror ./models/ myminio/model-artifacts/

# Set bucket policy
mc anonymous set download myminio/mlflow-artifacts
```

### Environment Variables
```yaml
# S3 endpoint
AWS_ENDPOINT_URL: http://minio:9000
S3_ENDPOINT: http://minio:9000

# Credentials
AWS_ACCESS_KEY_ID: <from secret>
AWS_SECRET_ACCESS_KEY: <from secret>

# Region
AWS_DEFAULT_REGION: us-east-1
```

---

## Cloud Migration Path

When migrating to AWS/Azure/GCP:

**Step 1**: Change endpoint
```yaml
# From:
AWS_ENDPOINT_URL: http://minio:9000

# To:
AWS_ENDPOINT_URL: https://s3.us-east-1.amazonaws.com
```

**Step 2**: Update credentials
```yaml
# Use IAM roles instead of static keys
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123:role/ml-service
```

**Step 3**: Migrate data
```bash
mc mirror minio/mlflow-artifacts/ s3://aws-mlflow-artifacts/
```

**No code changes required!** ✨

---

## Summary

| Component | Storage Type | Why |
|-----------|-------------|-----|
| PostgreSQL | PVC | Low latency, ACID |
| Redis | PVC | High IOPS |
| Kafka | PVC | Sequential writes |
| MLflow Artifacts | S3 | Large files, versioning |
| Airflow Logs | S3 | Long-term retention |
| Feature Store | S3 | Scalable parquet storage |
| Model Artifacts | S3 | Unlimited model versions |
| Backups | S3 | Durable offsite storage |

**Result**: Production-ready, cost-efficient, cloud-native storage architecture! 🎉
