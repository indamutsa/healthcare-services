# Level 4 Testing: Model Training & Model Serving

This guide covers testing the complete MLOps pipeline from model training through model serving.

## Prerequisites
- Docker and Docker Compose running
- All services from previous levels operational
- MLflow server accessible
- Feature store populated with data

## 1. Model Training Testing

### 1.1 Check Training Environment
```bash
# Verify MLflow server is running
docker-compose ps mlflow-server

# Check training service status
docker-compose ps ml-training

# Verify feature store data exists
curl -s http://localhost:9001/minio/health/live
```

### 1.2 Run Model Training
```bash
# Execute training pipeline
cd applications/ml-training
python train.py

# Alternative: Use training script
./scripts/train_model.sh
```

### 1.3 Verify Training Results
```bash
# Check MLflow experiments
curl -s http://localhost:5000/api/2.0/mlflow/experiments/list | jq .

# View latest runs
curl -s http://localhost:5000/api/2.0/mlflow/runs/search | jq '.runs[0:5]'

# Check model registry
curl -s http://localhost:5000/api/2.0/mlflow/registered-models/list | jq .
```

### 1.4 Expected Training Outputs
- ✅ Model trained and logged to MLflow
- ✅ Model registered in MLflow Model Registry
- ✅ Training metrics and artifacts stored
- ✅ Model transitioned to "Production" stage

## 2. Model Serving Testing

### 2.1 Health Check
```bash
# Test model-serving health endpoint
curl -s http://localhost:8000/health | jq .
```

**Expected Response:**
```json
{
  "status": "ok",
  "model": {
    "name": "adverse-event-predictor",
    "version": "1",
    "stage": "production",
    "run_id": "500cbb3d428c4fc6bc420c7e6de756ab"
  },
  "cache": {
    "enabled": true,
    "reachable": true
  }
}
```

### 2.2 Prediction Endpoint

#### Test with Correct Feature Count
```bash
# Create test data with 109 features (model expects 109 features)
curl -s -X POST http://localhost:8000/v1/predict \\
  -H "Content-Type: application/json" \\
  -d '{
    "records": [
      {
        "patient_id": "test_patient_001",
        "features": {
          "feature_0": 0.0,
          "feature_1": 0.0,
          "feature_2": 0.0,
          "feature_3": 0.0,
          "feature_4": 0.0,
          "feature_5": 0.0,
          "feature_6": 0.0,
          "feature_7": 0.0,
          "feature_8": 0.0,
          "feature_9": 0.0,
          "feature_10": 0.0,
          "feature_11": 0.0,
          "feature_12": 0.0,
          "feature_13": 0.0,
          "feature_14": 0.0,
          "feature_15": 0.0,
          "feature_16": 0.0,
          "feature_17": 0.0,
          "feature_18": 0.0,
          "feature_19": 0.0,
          "feature_20": 0.0,
          "feature_21": 0.0,
          "feature_22": 0.0,
          "feature_23": 0.0,
          "feature_24": 0.0,
          "feature_25": 0.0,
          "feature_26": 0.0,
          "feature_27": 0.0,
          "feature_28": 0.0,
          "feature_29": 0.0,
          "feature_30": 0.0,
          "feature_31": 0.0,
          "feature_32": 0.0,
          "feature_33": 0.0,
          "feature_34": 0.0,
          "feature_35": 0.0,
          "feature_36": 0.0,
          "feature_37": 0.0,
          "feature_38": 0.0,
          "feature_39": 0.0,
          "feature_40": 0.0,
          "feature_41": 0.0,
          "feature_42": 0.0,
          "feature_43": 0.0,
          "feature_44": 0.0,
          "feature_45": 0.0,
          "feature_46": 0.0,
          "feature_47": 0.0,
          "feature_48": 0.0,
          "feature_49": 0.0,
          "feature_50": 0.0,
          "feature_51": 0.0,
          "feature_52": 0.0,
          "feature_53": 0.0,
          "feature_54": 0.0,
          "feature_55": 0.0,
          "feature_56": 0.0,
          "feature_57": 0.0,
          "feature_58": 0.0,
          "feature_59": 0.0,
          "feature_60": 0.0,
          "feature_61": 0.0,
          "feature_62": 0.0,
          "feature_63": 0.0,
          "feature_64": 0.0,
          "feature_65": 0.0,
          "feature_66": 0.0,
          "feature_67": 0.0,
          "feature_68": 0.0,
          "feature_69": 0.0,
          "feature_70": 0.0,
          "feature_71": 0.0,
          "feature_72": 0.0,
          "feature_73": 0.0,
          "feature_74": 0.0,
          "feature_75": 0.0,
          "feature_76": 0.0,
          "feature_77": 0.0,
          "feature_78": 0.0,
          "feature_79": 0.0,
          "feature_80": 0.0,
          "feature_81": 0.0,
          "feature_82": 0.0,
          "feature_83": 0.0,
          "feature_84": 0.0,
          "feature_85": 0.0,
          "feature_86": 0.0,
          "feature_87": 0.0,
          "feature_88": 0.0,
          "feature_89": 0.0,
          "feature_90": 0.0,
          "feature_91": 0.0,
          "feature_92": 0.0,
          "feature_93": 0.0,
          "feature_94": 0.0,
          "feature_95": 0.0,
          "feature_96": 0.0,
          "feature_97": 0.0,
          "feature_98": 0.0,
          "feature_99": 0.0,
          "feature_100": 0.0,
          "feature_101": 0.0,
          "feature_102": 0.0,
          "feature_103": 0.0,
          "feature_104": 0.0,
          "feature_105": 0.0,
          "feature_106": 0.0,
          "feature_107": 0.0,
          "feature_108": 0.0
        },
        "metadata": {
          "timestamp": "2024-01-15T10:30:00Z",
          "source": "clinical_trial_site_a"
        }
      }
    ],
    "use_cache": true
  }'
```

**Expected Response:**
```json
{
  "model": {
    "name": "adverse-event-predictor",
    "version": "1",
    "stage": "production",
    "run_id": "500cbb3d428c4fc6bc420c7e6de756ab",
    "loaded_at": "2025-10-25T16:35:46.305263"
  },
  "results": [
    {
      "patient_id": "test_patient_001",
      "probability": 0.0,
      "predicted_class": 0,
      "threshold": 0.5,
      "metadata": {
        "timestamp": "2024-01-15T10:30:00Z",
        "source": "clinical_trial_site_a"
      },
      "explanation": null
    }
  ],
  "cached": false
}
```

### 2.3 Test Caching Functionality
```bash
# Repeat the same prediction request to test caching
curl -s -X POST http://localhost:8000/v1/predict \\
  -H "Content-Type: application/json" \\
  -d '{
    "records": [
      {
        "patient_id": "test_patient_001",
        "features": {
          "feature_0": 0.0,
          "feature_1": 0.0,
          "feature_2": 0.0,
          "feature_3": 0.0,
          "feature_4": 0.0,
          "feature_5": 0.0,
          "feature_6": 0.0,
          "feature_7": 0.0,
          "feature_8": 0.0,
          "feature_9": 0.0,
          "feature_10": 0.0,
          "feature_11": 0.0,
          "feature_12": 0.0,
          "feature_13": 0.0,
          "feature_14": 0.0,
          "feature_15": 0.0,
          "feature_16": 0.0,
          "feature_17": 0.0,
          "feature_18": 0.0,
          "feature_19": 0.0,
          "feature_20": 0.0,
          "feature_21": 0.0,
          "feature_22": 0.0,
          "feature_23": 0.0,
          "feature_24": 0.0,
          "feature_25": 0.0,
          "feature_26": 0.0,
          "feature_27": 0.0,
          "feature_28": 0.0,
          "feature_29": 0.0,
          "feature_30": 0.0,
          "feature_31": 0.0,
          "feature_32": 0.0,
          "feature_33": 0.0,
          "feature_34": 0.0,
          "feature_35": 0.0,
          "feature_36": 0.0,
          "feature_37": 0.0,
          "feature_38": 0.0,
          "feature_39": 0.0,
          "feature_40": 0.0,
          "feature_41": 0.0,
          "feature_42": 0.0,
          "feature_43": 0.0,
          "feature_44": 0.0,
          "feature_45": 0.0,
          "feature_46": 0.0,
          "feature_47": 0.0,
          "feature_48": 0.0,
          "feature_49": 0.0,
          "feature_50": 0.0,
          "feature_51": 0.0,
          "feature_52": 0.0,
          "feature_53": 0.0,
          "feature_54": 0.0,
          "feature_55": 0.0,
          "feature_56": 0.0,
          "feature_57": 0.0,
          "feature_58": 0.0,
          "feature_59": 0.0,
          "feature_60": 0.0,
          "feature_61": 0.0,
          "feature_62": 0.0,
          "feature_63": 0.0,
          "feature_64": 0.0,
          "feature_65": 0.0,
          "feature_66": 0.0,
          "feature_67": 0.0,
          "feature_68": 0.0,
          "feature_69": 0.0,
          "feature_70": 0.0,
          "feature_71": 0.0,
          "feature_72": 0.0,
          "feature_73": 0.0,
          "feature_74": 0.0,
          "feature_75": 0.0,
          "feature_76": 0.0,
          "feature_77": 0.0,
          "feature_78": 0.0,
          "feature_79": 0.0,
          "feature_80": 0.0,
          "feature_81": 0.0,
          "feature_82": 0.0,
          "feature_83": 0.0,
          "feature_84": 0.0,
          "feature_85": 0.0,
          "feature_86": 0.0,
          "feature_87": 0.0,
          "feature_88": 0.0,
          "feature_89": 0.0,
          "feature_90": 0.0,
          "feature_91": 0.0,
          "feature_92": 0.0,
          "feature_93": 0.0,
          "feature_94": 0.0,
          "feature_95": 0.0,
          "feature_96": 0.0,
          "feature_97": 0.0,
          "feature_98": 0.0,
          "feature_99": 0.0,
          "feature_100": 0.0,
          "feature_101": 0.0,
          "feature_102": 0.0,
          "feature_103": 0.0,
          "feature_104": 0.0,
          "feature_105": 0.0,
          "feature_106": 0.0,
          "feature_107": 0.0,
          "feature_108": 0.0
        },
        "metadata": {
          "timestamp": "2024-01-15T10:30:00Z",
          "source": "clinical_trial_site_a"
        }
      }
    ],
    "use_cache": true
  }'
```

**Expected Response (Cached):**
```json
{
  "model": {
    "name": "adverse-event-predictor",
    "version": "1",
    "stage": "production",
    "run_id": "500cbb3d428c4fc6bc420c7e6de756ab",
    "loaded_at": "2025-10-25T16:35:46.305263"
  },
  "results": [
    {
      "patient_id": "test_patient_001",
      "probability": 0.0,
      "predicted_class": 0,
      "threshold": 0.5,
      "metadata": {
        "timestamp": "2024-01-15T10:30:00Z",
        "source": "clinical_trial_site_a"
      },
      "explanation": null
    }
  ],
  "cached": true
}
```

### 2.4 API Documentation
```bash
# Access API documentation
curl -s http://localhost:8000/docs
```

## 3. Integration Testing

### 3.1 End-to-End Pipeline Test
```bash
# 1. Verify data ingestion is working
curl -s http://localhost:8080/health  # Clinical Data Gateway

# 2. Check feature engineering
curl -s http://localhost:8081/health  # Feature Engineering Service

# 3. Verify model serving
curl -s http://localhost:8000/health  # Model Serving

# 4. Test complete prediction flow
curl -s -X POST http://localhost:8000/v1/predict \\
  -H "Content-Type: application/json" \\
  -d @test-data/clinical-samples/valid-clinical-data.json
```

### 3.2 Performance Testing
```bash
# Test with multiple records
curl -s -X POST http://localhost:8000/v1/predict \\
  -H "Content-Type: application/json" \\
  -d @test-data/performance-test/high-volume-data.json

# Monitor response times and memory usage
docker stats model-serving
```

## 4. Troubleshooting

### Common Issues

#### Model Loading Failures
```bash
# Check MLflow connectivity
docker-compose exec model-serving python -c "
import mlflow
mlflow.set_tracking_uri('http://mlflow-server:5000')
try:
    model = mlflow.pyfunc.load_model('models:/adverse-event-predictor/production')
    print('✓ Model loaded successfully')
except Exception as e:
    print(f'✗ Model loading failed: {e}')
"
```

#### Redis Connection Issues
```bash
# Test Redis connectivity
docker-compose exec redis redis-cli ping

# Check Redis logs
docker-compose logs redis
```

#### Feature Mismatch
```bash
# Verify feature count
docker-compose exec model-serving python -c "
import mlflow
mlflow.set_tracking_uri('http://mlflow-server:5000')
model = mlflow.pyfunc.load_model('models:/adverse-event-predictor/production')

# Try to get feature information
if hasattr(model, '_model_impl'):
    xgb_model = model._model_impl
    if hasattr(xgb_model, 'get_booster'):
        booster = xgb_model.get_booster()
        print(f'Expected features: {booster.num_features()}')
"
```

## 5. Success Criteria

### ✅ Model Training
- [ ] Training pipeline executes without errors
- [ ] Model metrics logged to MLflow
- [ ] Model registered in MLflow Model Registry
- [ ] Model transitioned to "Production" stage

### ✅ Model Serving
- [ ] Health endpoint returns `{"status": "ok"}`
- [ ] Prediction endpoint accepts valid requests
- [ ] Responses include proper probability scores
- [ ] Caching mechanism works (Redis)
- [ ] API documentation accessible

### ✅ Integration
- [ ] End-to-end prediction flow works
- [ ] Multiple records processed correctly
- [ ] Performance meets requirements (< 500ms response time)
- [ ] Error handling for malformed requests

## 6. Next Steps

After successful Level 4 testing:
1. **Level 5**: Monitoring and Observability
2. **Level 6**: Model Retraining Pipeline
3. **Level 7**: Production Deployment

---

**Maintenance Notes:**
- Monitor model performance drift
- Set up automated retraining triggers
- Configure alerting for service failures
- Regular backup of MLflow artifacts and model registry