#!/bin/bash
set -e

echo "Installing MLflow and dependencies..."
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir "mlflow[extras]==2.8.1" boto3 psycopg2-binary

echo "Starting MLflow server on 0.0.0.0:5000..."
exec gunicorn \
  --bind 0.0.0.0:5000 \
  --workers 4 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile - \
  "mlflow.server:app(\
    backend_store_uri='postgresql://mlflow:mlflow@postgres-mlflow:5432/mlflow',\
    default_artifact_root='s3://mlflow-artifacts/'\
  )"
