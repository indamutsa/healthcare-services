#!/bin/bash

# Deploy all application layers to Kubernetes
set -e

echo "🚀 Deploying Clinical Trials MLOps Platform - All Layers"
echo "======================================================"

# Create namespace if it doesn't exist
echo "📦 Creating clinical-mlops namespace..."
kubectl create namespace clinical-mlops --dry-run=client -o yaml | kubectl apply -f -

# Deploy infrastructure layer (Level 0)
echo "🔧 Deploying Infrastructure Layer (Level 0)..."
kubectl apply -f kubernetes-manifests/infrastructure/ -n clinical-mlops

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure services to be ready..."
kubectl wait --for=condition=ready pod -l tier=infrastructure -n clinical-mlops --timeout=300s

# Deploy data ingestion layer (Level 1)
echo "📥 Deploying Data Ingestion Layer (Level 1)..."
kubectl apply -f kubernetes-manifests/data-ingestion/ -n clinical-mlops

# Deploy data processing layer (Level 2)
echo "⚙️ Deploying Data Processing Layer (Level 2)..."
kubectl apply -f kubernetes-manifests/data-processing/ -n clinical-mlops

# Deploy feature engineering layer (Level 3)
echo "🔬 Deploying Feature Engineering Layer (Level 3)..."
kubectl apply -f kubernetes-manifests/feature-engineering/ -n clinical-mlops

# Deploy ML pipeline layer (Level 4)
echo "🤖 Deploying ML Pipeline Layer (Level 4)..."
kubectl apply -f kubernetes-manifests/ml-pipeline/ -n clinical-mlops

# Deploy orchestration layer (Level 5)
echo "🔄 Deploying Orchestration Layer (Level 5)..."
kubectl apply -f kubernetes-manifests/orchestration/ -n clinical-mlops

# Deploy observability layer (Level 6)
echo "📊 Deploying Observability Layer (Level 6)..."
kubectl apply -f kubernetes-manifests/observability/ -n clinical-mlops

echo "✅ All layers deployed successfully!"
echo ""
echo "📋 Checking deployment status..."
kubectl get pods -n clinical-mlops --sort-by=.metadata.creationTimestamp

echo ""
echo "🔗 Services available:"
echo "  - Clinical Gateway: kubectl port-forward svc/clinical-data-gateway 8080:80 -n clinical-mlops"
echo "  - MLflow: kubectl port-forward svc/mlflow 5000:5000 -n clinical-mlops"
echo "  - Airflow: kubectl port-forward svc/airflow-webserver 8081:8080 -n clinical-mlops"
echo "  - Model Serving: kubectl port-forward svc/model-serving 8000:80 -n clinical-mlops"