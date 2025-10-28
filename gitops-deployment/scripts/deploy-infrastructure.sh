#!/bin/bash

# Infrastructure Deployment Script for Clinical Trials MLOps Platform

set -e

echo "🚀 Deploying Infrastructure Layer (Level 0)..."

# Create infrastructure namespace if it doesn't exist
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL MLFlow
echo "📦 Deploying PostgreSQL MLFlow..."
kubectl apply -f kubernetes-manifests/infrastructure/postgres-mlflow.yaml

# Deploy Redis
echo "🔴 Deploying Redis..."
kubectl apply -f kubernetes-manifests/infrastructure/redis.yaml

# Deploy MinIO
echo "📦 Deploying MinIO..."
kubectl apply -f kubernetes-manifests/infrastructure/minio.yaml

# Deploy Kafka and Zookeeper
echo "📊 Deploying Kafka and Zookeeper..."
kubectl apply -f kubernetes-manifests/infrastructure/kafka.yaml

# Wait for services to be ready
echo "⏳ Waiting for infrastructure services to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres-mlflow -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=minio -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=zookeeper -n infrastructure --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka -n infrastructure --timeout=300s

echo "✅ Infrastructure Layer deployed successfully!"
echo ""
echo "📋 Infrastructure Services:"
echo "   - PostgreSQL MLFlow: postgres-mlflow.infrastructure.svc.cluster.local:5432"
echo "   - Redis: redis.infrastructure.svc.cluster.local:6379"
echo "   - MinIO: minio.infrastructure.svc.cluster.local:9000"
echo "   - Kafka: kafka.infrastructure.svc.cluster.local:9092"
echo "   - Zookeeper: zookeeper.infrastructure.svc.cluster.local:2181"