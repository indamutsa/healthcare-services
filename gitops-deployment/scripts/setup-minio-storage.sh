#!/bin/bash

# Setup MinIO S3 Storage for Clinical MLOps Platform
# This script configures MinIO as the object storage backend

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-clinical-mlops}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🗄️  Setting up MinIO S3 Storage for Clinical MLOps${NC}"
echo "===================================================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v mc &> /dev/null; then
    echo -e "${YELLOW}⚠️  MinIO Client (mc) not found. Installing...${NC}"
    wget https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    sudo mv mc /usr/local/bin/
    echo -e "${GREEN}✅ MinIO Client installed${NC}"
fi

# Check if MinIO is running
echo -e "${YELLOW}🔍 Checking MinIO deployment...${NC}"
if ! kubectl get deployment minio -n ${NAMESPACE} &> /dev/null; then
    echo -e "${RED}❌ MinIO deployment not found. Please deploy MinIO first.${NC}"
    echo "   Run: kubectl apply -f ../kubernetes-manifests/infrastructure/minio.yaml"
    exit 1
fi

# Wait for MinIO to be ready
echo -e "${YELLOW}⏳ Waiting for MinIO to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=minio -n ${NAMESPACE} --timeout=300s

# Port forward MinIO
echo -e "${YELLOW}🔌 Setting up port forward to MinIO...${NC}"
kubectl port-forward -n ${NAMESPACE} svc/minio 9000:9000 &
PF_PID=$!
sleep 5

# Cleanup on exit
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Get MinIO credentials
echo -e "${YELLOW}🔐 Retrieving MinIO credentials...${NC}"
MINIO_ACCESS_KEY=$(kubectl get secret minio-credentials -n ${NAMESPACE} -o jsonpath='{.data.accessKey}' | base64 -d)
MINIO_SECRET_KEY=$(kubectl get secret minio-credentials -n ${NAMESPACE} -o jsonpath='{.data.secretKey}' | base64 -d)

# Configure mc alias
echo -e "${YELLOW}⚙️  Configuring MinIO client...${NC}"
mc alias set k8s-minio http://localhost:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

# Create buckets
echo -e "${GREEN}📦 Creating MinIO buckets...${NC}"

BUCKETS=(
    "mlflow-artifacts:Indefinite:MLflow experiment artifacts and model files"
    "model-artifacts:90d:Production model versions"
    "airflow-logs:30d:Airflow task execution logs"
    "feature-store:30d:Offline feature store (parquet files)"
    "training-data:90d:Historical training datasets"
    "backups:30d:Database and volume backups"
    "kubernetes-volumes:Varies:CSI-provisioned volumes"
)

for bucket_info in "${BUCKETS[@]}"; do
    IFS=':' read -r bucket retention description <<< "$bucket_info"

    echo -e "  📁 Creating bucket: ${GREEN}${bucket}${NC}"
    mc mb k8s-minio/${bucket} --ignore-existing

    # Set lifecycle policy for retention
    if [ "$retention" != "Indefinite" ] && [ "$retention" != "Varies" ]; then
        days=$(echo $retention | grep -o '[0-9]*')
        echo "     Setting retention: ${days} days"
        mc ilm add k8s-minio/${bucket} --expiry-days ${days}
    fi

    # Set bucket tags
    mc tag set k8s-minio/${bucket} "purpose=${description}"

    echo -e "     ${GREEN}✅ ${bucket}${NC} - ${description}"
done

# Set bucket policies
echo -e "${GREEN}🔒 Configuring bucket policies...${NC}"

# Public read for MLflow artifacts (for easy access)
mc anonymous set download k8s-minio/mlflow-artifacts
echo -e "  ✅ mlflow-artifacts: Public read access"

# Public read for model artifacts (for serving)
mc anonymous set download k8s-minio/model-artifacts
echo -e "  ✅ model-artifacts: Public read access"

# Private for everything else
for bucket in airflow-logs feature-store training-data backups kubernetes-volumes; do
    mc anonymous set private k8s-minio/${bucket}
    echo -e "  ✅ ${bucket}: Private access only"
done

# Enable versioning for critical buckets
echo -e "${GREEN}📚 Enabling versioning for critical buckets...${NC}"
for bucket in mlflow-artifacts model-artifacts backups; do
    mc version enable k8s-minio/${bucket}
    echo -e "  ✅ ${bucket}: Versioning enabled"
done

# Upload test files
echo -e "${GREEN}🧪 Uploading test files...${NC}"
echo "This is a test file" > /tmp/test.txt

mc cp /tmp/test.txt k8s-minio/mlflow-artifacts/test/test.txt
mc cp /tmp/test.txt k8s-minio/model-artifacts/test/test.txt

rm /tmp/test.txt

# Display bucket information
echo ""
echo -e "${GREEN}📊 MinIO Storage Summary${NC}"
echo "===================================================="
mc ls k8s-minio/ | while read -r line; do
    bucket=$(echo $line | awk '{print $NF}' | tr -d '/')
    size=$(mc du k8s-minio/${bucket} 2>/dev/null | awk '{print $1, $2}' || echo "0 B")
    objects=$(mc ls k8s-minio/${bucket} --recursive 2>/dev/null | wc -l || echo "0")
    echo -e "  📁 ${GREEN}${bucket}${NC}"
    echo "     Size: ${size}"
    echo "     Objects: ${objects}"
    echo ""
done

# Create ConfigMap with MinIO configuration
echo -e "${YELLOW}📝 Creating MinIO configuration ConfigMap...${NC}"
kubectl create configmap minio-config -n ${NAMESPACE} \
    --from-literal=endpoint=http://minio:9000 \
    --from-literal=region=us-east-1 \
    --from-literal=bucket-mlflow=mlflow-artifacts \
    --from-literal=bucket-models=model-artifacts \
    --from-literal=bucket-airflow=airflow-logs \
    --from-literal=bucket-features=feature-store \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ MinIO configuration ConfigMap created${NC}"

# Display connection information
echo ""
echo -e "${GREEN}🎉 MinIO S3 Storage Setup Complete!${NC}"
echo "===================================================="
echo ""
echo -e "${GREEN}📋 Connection Information:${NC}"
echo "   Endpoint (Internal): http://minio.${NAMESPACE}.svc.cluster.local:9000"
echo "   Endpoint (External): http://localhost:9000 (via port-forward)"
echo "   Console: http://localhost:9001"
echo "   Access Key: ${MINIO_ACCESS_KEY}"
echo "   Secret Key: ${MINIO_SECRET_KEY}"
echo ""
echo -e "${GREEN}🪣 Created Buckets:${NC}"
for bucket_info in "${BUCKETS[@]}"; do
    IFS=':' read -r bucket retention description <<< "$bucket_info"
    echo "   - ${bucket} (${retention}): ${description}"
done
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "   1. Update your applications to use MinIO S3 endpoints"
echo "   2. Deploy S3-enabled manifests:"
echo "      kubectl apply -f ../kubernetes-manifests/ml-pipeline/mlflow-s3.yaml"
echo "      kubectl apply -f ../kubernetes-manifests/orchestration/airflow-s3-logs.yaml"
echo "      kubectl apply -f ../kubernetes-manifests/feature-engineering/feature-store-s3.yaml"
echo "      kubectl apply -f ../kubernetes-manifests/ml-pipeline/model-serving-s3.yaml"
echo ""
echo "   3. Access MinIO Console:"
echo "      kubectl port-forward -n ${NAMESPACE} svc/minio 9001:9001"
echo "      Open: http://localhost:9001"
echo ""
echo -e "${GREEN}📚 Documentation:${NC}"
echo "   - Storage Architecture: ../STORAGE_ARCHITECTURE.md"
echo "   - MinIO Docs: https://min.io/docs/minio/kubernetes/upstream/"
echo ""

# Keep port-forward alive
echo -e "${YELLOW}⏳ Keeping port-forward alive. Press Ctrl+C to exit...${NC}"
wait $PF_PID
