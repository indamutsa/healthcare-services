#!/bin/bash

# Generate Secure Kubernetes Secrets for Clinical MLOps Platform
#
# This script generates secure random passwords and creates Kubernetes Secret manifests.
# The generated secrets should be stored securely (e.g., in a secrets manager) and
# applied to the cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../kubernetes-manifests/infrastructure"
SECRETS_FILE="${OUTPUT_DIR}/secrets-generated.yaml"

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Generating Secure Secrets for Clinical MLOps Platform${NC}"
echo "=================================================="

# Function to generate random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-${length}
}

# Function to base64 encode
b64encode() {
    echo -n "$1" | base64 -w 0
}

# Generate passwords
echo "Generating secure passwords..."
MINIO_ACCESS_KEY=$(generate_password 20)
MINIO_SECRET_KEY=$(generate_password 40)
POSTGRES_MLFLOW_PASSWORD=$(generate_password 32)
POSTGRES_AIRFLOW_PASSWORD=$(generate_password 32)
REDIS_PASSWORD=$(generate_password 32)
KAFKA_PASSWORD=$(generate_password 32)
JWT_SECRET=$(generate_password 64)
MODEL_SERVING_API_KEY=$(generate_password 40)
GRAFANA_ADMIN_PASSWORD=$(generate_password 24)

# Create secrets manifest
cat > "${SECRETS_FILE}" <<EOF
# Auto-generated Kubernetes Secrets
# Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
#
# CRITICAL SECURITY NOTICE:
# - DO NOT commit this file to version control!
# - Store these secrets securely in a secrets manager
# - Use Sealed Secrets or External Secrets Operator in production
# - Rotate secrets regularly

---
# MinIO Credentials
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: clinical-mlops
  labels:
    app: minio
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  accessKey: $(b64encode "${MINIO_ACCESS_KEY}")
  secretKey: $(b64encode "${MINIO_SECRET_KEY}")

---
# PostgreSQL MLflow Credentials
apiVersion: v1
kind: Secret
metadata:
  name: postgres-mlflow-credentials
  namespace: clinical-mlops
  labels:
    app: postgres-mlflow
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  username: $(b64encode "mlflow_user")
  password: $(b64encode "${POSTGRES_MLFLOW_PASSWORD}")
  database: $(b64encode "mlflow_db")
  connection-string: $(b64encode "postgresql://mlflow_user:${POSTGRES_MLFLOW_PASSWORD}@postgres-mlflow:5432/mlflow_db")

---
# PostgreSQL Airflow Credentials
apiVersion: v1
kind: Secret
metadata:
  name: postgres-airflow-credentials
  namespace: clinical-mlops
  labels:
    app: postgres-airflow
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  username: $(b64encode "airflow_user")
  password: $(b64encode "${POSTGRES_AIRFLOW_PASSWORD}")
  database: $(b64encode "airflow_db")
  connection-string: $(b64encode "postgresql://airflow_user:${POSTGRES_AIRFLOW_PASSWORD}@postgres-airflow:5432/airflow_db")

---
# Redis Credentials
apiVersion: v1
kind: Secret
metadata:
  name: redis-credentials
  namespace: clinical-mlops
  labels:
    app: redis
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  password: $(b64encode "${REDIS_PASSWORD}")
  connection-string: $(b64encode "redis://:${REDIS_PASSWORD}@redis:6379/0")

---
# Kafka Credentials
apiVersion: v1
kind: Secret
metadata:
  name: kafka-credentials
  namespace: clinical-mlops
  labels:
    app: kafka
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  username: $(b64encode "kafka_admin")
  password: $(b64encode "${KAFKA_PASSWORD}")

---
# Clinical Data Gateway Secrets
apiVersion: v1
kind: Secret
metadata:
  name: clinical-gateway-secrets
  namespace: clinical-mlops
  labels:
    app: clinical-data-gateway
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  jwt-secret: $(b64encode "${JWT_SECRET}")
  database-url: $(b64encode "postgresql://mlflow_user:${POSTGRES_MLFLOW_PASSWORD}@postgres-mlflow:5432/mlflow_db")
  redis-url: $(b64encode "redis://:${REDIS_PASSWORD}@redis:6379/0")

---
# Model Serving Secrets
apiVersion: v1
kind: Secret
metadata:
  name: model-serving-secrets
  namespace: clinical-mlops
  labels:
    app: model-serving
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  api-key: $(b64encode "${MODEL_SERVING_API_KEY}")

---
# Grafana Admin Credentials
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
  namespace: clinical-mlops
  labels:
    app: grafana
    managed-by: gitops
    generated: "true"
type: Opaque
data:
  admin-user: $(b64encode "admin")
  admin-password: $(b64encode "${GRAFANA_ADMIN_PASSWORD}")
EOF

echo -e "${GREEN}✅ Secrets generated successfully!${NC}"
echo ""
echo -e "${YELLOW}📝 Generated secrets file: ${SECRETS_FILE}${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT SECURITY STEPS:${NC}"
echo "1. Store the generated credentials securely (password manager, secrets vault)"
echo "2. DO NOT commit ${SECRETS_FILE} to version control"
echo "3. Add ${SECRETS_FILE} to .gitignore"
echo "4. For production, use Sealed Secrets or External Secrets Operator"
echo "5. Rotate these secrets regularly (every 90 days recommended)"
echo ""
echo -e "${GREEN}📋 Generated Credentials:${NC}"
echo "=================================================="
echo "MinIO Access Key: ${MINIO_ACCESS_KEY}"
echo "MinIO Secret Key: ${MINIO_SECRET_KEY}"
echo "PostgreSQL MLflow Password: ${POSTGRES_MLFLOW_PASSWORD}"
echo "PostgreSQL Airflow Password: ${POSTGRES_AIRFLOW_PASSWORD}"
echo "Redis Password: ${REDIS_PASSWORD}"
echo "Kafka Password: ${KAFKA_PASSWORD}"
echo "JWT Secret: ${JWT_SECRET}"
echo "Model Serving API Key: ${MODEL_SERVING_API_KEY}"
echo "Grafana Admin Password: ${GRAFANA_ADMIN_PASSWORD}"
echo "=================================================="
echo ""
echo -e "${YELLOW}💡 To apply secrets to cluster:${NC}"
echo "kubectl apply -f ${SECRETS_FILE}"
echo ""
echo -e "${YELLOW}💡 To convert to Sealed Secrets:${NC}"
echo "kubeseal --format=yaml < ${SECRETS_FILE} > ${OUTPUT_DIR}/sealed-secrets.yaml"
echo ""

# Add to gitignore
if [ ! -f "${SCRIPT_DIR}/../../.gitignore" ]; then
    echo "secrets-generated.yaml" >> "${SCRIPT_DIR}/../../.gitignore"
    echo -e "${GREEN}✅ Added secrets-generated.yaml to .gitignore${NC}"
fi
