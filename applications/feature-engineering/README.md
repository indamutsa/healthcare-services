# Feature Engineering Pipeline

Generate 120+ ML features from clinical trial data.

## Quick Start
```bash
# Start feature engineering
docker-compose --profile feature-engineering up -d

# Monitor progress
./scripts/monitor_pipeline.sh

# Test the pipeline
./scripts/test_end_to_end.sh
```

## Testing & Visualization
```bash
# Test feature stores
./scripts/test_feature_store.sh

# Visualize features for a date
./scripts/visualize_features.sh 2025-10-07

# Query specific patient
./scripts/query_features.sh PT00042 2025-10-07

# Compare stores
./scripts/compare_stores.sh 2025-10-07
```

## Feature Store Access

### Offline Store (MinIO)
- **Location**: `s3://clinical-mlops/features/offline/`
- **Format**: Parquet (compressed)
- **Access**: Via Spark or AWS CLI

### Online Store (Redis)
- **Location**: `redis://localhost:6379`
- **Key Pattern**: `patient:{patient_id}:features`
- **TTL**: 48 hours
- **UI**: http://localhost:5540

## Generated Features

- **Temporal Features**: 60+ (rolling windows: 1h, 6h, 24h)
- **Lab Features**: 25+ (latest values, trends, abnormal counts)
- **Medication Features**: 10+ (current meds, interactions)
- **Context Features**: 5+ (demographics, trial info)
- **Derived Features**: 20+ (interactions, scores)

Total: **120+ features**

## Outputs

- **Offline Store**: Parquet files partitioned by date
- **Online Store**: Redis hashes with latest features
- **Metadata**: `data/feature_metadata.json`
- **Visualizations**: `visualizations/` directory

```sh
# 1. Start Redis UI
docker-compose up -d redis-insight

# 2. Access Redis UI at http://localhost:5540

# 3. Run tests
cd applications/feature-engineering
./scripts/test_feature_store.sh
./scripts/test_end_to_end.sh

# 4. Visualize features
./scripts/visualize_features.sh 2025-10-07
```