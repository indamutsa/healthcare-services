#!/bin/bash

# Docker Compose to Kubernetes Conversion Script
# This script converts docker-compose services to Kubernetes manifests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../kubernetes-manifests/base"

echo "🔧 Converting Docker Compose services to Kubernetes manifests..."

# Check if kompose is installed
if ! command -v kompose &> /dev/null; then
    echo "❌ Kompose is not installed. Installing..."
    # Install kompose
    curl -L https://github.com/kubernetes/kompose/releases/download/v1.31.2/kompose-linux-amd64 -o kompose
    chmod +x kompose
    sudo mv kompose /usr/local/bin/
fi

# Create output directories
mkdir -p "$OUTPUT_DIR/infrastructure"
mkdir -p "$OUTPUT_DIR/data-ingestion"
mkdir -p "$OUTPUT_DIR/data-processing"
mkdir -p "$OUTPUT_DIR/ml-pipeline"
mkdir -p "$OUTPUT_DIR/orchestration"
mkdir -p "$OUTPUT_DIR/observability"

# Function to convert specific services
declare -A SERVICE_MAPPING=(
    ["minio"]="infrastructure"
    ["minio-setup"]="infrastructure"
    ["postgres-mlflow"]="infrastructure"
    ["postgres-airflow"]="infrastructure"
    ["redis"]="infrastructure"
    ["redis-insight"]="infrastructure"
    ["zookeeper"]="infrastructure"
    ["kafka"]="infrastructure"
    ["kafka-ui"]="infrastructure"
    ["kafka-producer"]="data-ingestion"
    ["kafka-consumer"]="data-ingestion"
    ["clinical-mq"]="data-ingestion"
    ["clinical-data-gateway"]="data-ingestion"
    ["lab-results-processor"]="data-ingestion"
    ["clinical-data-generator"]="data-ingestion"
    ["spark-master"]="data-processing"
    ["spark-worker"]="data-processing"
    ["spark-streaming"]="data-processing"
    ["spark-batch"]="data-processing"
    ["feature-engineering"]="ml-pipeline"
    ["mlflow-server"]="ml-pipeline"
    ["ml-training"]="ml-pipeline"
    ["model-serving"]="ml-pipeline"
    ["airflow-init"]="orchestration"
    ["airflow-webserver"]="orchestration"
    ["airflow-scheduler"]="orchestration"
    ["prometheus"]="observability"
    ["grafana"]="observability"
    ["monitoring-service"]="observability"
    ["opensearch"]="observability"
    ["opensearch-dashboards"]="observability"
    ["data-prepper"]="observability"
    ["filebeat"]="observability"
    ["cadvisor"]="observability"
    ["node-exporter"]="observability"
)

# Convert infrastructure services first
echo "📦 Converting infrastructure services..."
cd "$PROJECT_ROOT"

# Create a temporary docker-compose file for infrastructure services
cat > docker-compose-infrastructure.yml << 'EOF'
version: '3.8'
services:
  minio:
    image: minio/minio:RELEASE.2025-09-07T16-13-09Z-cpuv1
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio-data:/data
    networks:
      - mlops-network

  postgres-mlflow:
    image: postgres:15-alpine
    container_name: postgres-mlflow
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflow
    ports:
      - "5432:5432"
    networks:
      - mlops-network

  postgres-airflow:
    image: postgres:15-alpine
    container_name: postgres-airflow
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    ports:
      - "5433:5432"
    networks:
      - mlops-network

  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    networks:
      - mlops-network

  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    networks:
      - mlops-network

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    container_name: kafka
    depends_on:
      - zookeeper
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
    networks:
      - mlops-network

networks:
  mlops-network:
    driver: bridge

volumes:
  minio-data:
EOF

# Convert infrastructure services
kompose convert -f docker-compose-infrastructure.yml -o "$OUTPUT_DIR/infrastructure/"

# Clean up temporary file
rm docker-compose-infrastructure.yml

# Post-process the generated manifests
echo "🔧 Post-processing generated manifests..."

# Function to add namespace and labels to manifests
add_namespace_and_labels() {
    local dir="$1"
    local namespace="$2"
    
    for file in "$dir"/*.yaml; do
        if [[ -f "$file" ]]; then
            # Add namespace to resources that support it
            if grep -q "kind: Deployment" "$file" || grep -q "kind: StatefulSet" "$file" || grep -q "kind: Service" "$file"; then
                # Add namespace
                sed -i "/^metadata:/a\  namespace: $namespace" "$file"
                
                # Add labels
                sed -i "/^  namespace: $namespace/a\  labels:\n    app.kubernetes.io/part-of: clinical-mlops\n    app.kubernetes.io/managed-by: gitops" "$file"
            fi
        fi
    done
}

# Process each directory
add_namespace_and_labels "$OUTPUT_DIR/infrastructure" "infrastructure"

# Create namespace manifests
echo "📁 Creating namespace manifests..."

cat > "$OUTPUT_DIR/infrastructure/00-namespace.yaml" << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: data-ingestion
  labels:
    name: data-ingestion
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: data-processing
  labels:
    name: data-processing
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-pipeline
  labels:
    name: ml-pipeline
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: orchestration
  labels:
    name: orchestration
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    app.kubernetes.io/part-of: clinical-mlops
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    app.kubernetes.io/part-of: clinical-mlops
EOF

echo "✅ Conversion complete!"
echo ""
echo "📋 Generated manifests location: $OUTPUT_DIR"
echo ""
echo "🔧 Next Steps:"
echo "   1. Review and customize the generated manifests"
echo "   2. Create Helm charts from the manifests"
echo "   3. Set up ArgoCD applications"
echo "   4. Deploy to your Kubernetes cluster"