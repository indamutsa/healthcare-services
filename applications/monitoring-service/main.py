from fastapi import FastAPI
from prometheus_client import make_asgi_app, Gauge, Counter, Histogram
import asyncio
import requests
import json
import time
from datetime import datetime

app = FastAPI(title="Monitoring Service")

# Custom metrics
drift_score = Gauge('model_drift_score', 'Drift score', ['model'])
data_quality = Gauge('data_quality_score', 'Quality score', ['source'])
prediction_latency = Histogram('prediction_duration_seconds', 'Prediction latency')
predictions_total = Counter('predictions_total', 'Total predictions', ['model', 'status'])
cache_hits_total = Counter('cache_hits_total', 'Cache hits', ['model'])

# Mount Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

@app.get("/")
async def root():
    return {"message": "Monitoring Service", "status": "healthy"}

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

async def monitor_loop():
    while True:
        try:
            # Simulate monitoring checks
            drift_score.labels(model='clinical_model').set(0.05)  # 5% drift
            data_quality.labels(source='clinical_data').set(0.95)  # 95% quality
            data_quality.labels(source='lab_results').set(0.92)   # 92% quality
            
            # Simulate some predictions
            predictions_total.labels(model='clinical_model', status='success').inc(10)
            cache_hits_total.labels(model='clinical_model').inc(7)
            
        except Exception as e:
            print(f"Monitoring error: {e}")
        
        await asyncio.sleep(60)

@app.on_event("startup")
async def startup():
    asyncio.create_task(monitor_loop())