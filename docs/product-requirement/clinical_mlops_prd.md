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
- **Orchestration**: Kubeflow Pipelines (workflow automation)
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