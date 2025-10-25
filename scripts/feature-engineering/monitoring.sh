#!/bin/bash
#
# Monitor Feature Engineering Pipeline end-to-end
#

set -euo pipefail

FEATURE_ENGINEERING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${FEATURE_ENGINEERING_SCRIPT_DIR}/.." && pwd)"
COMMON_DIR="${ROOT_DIR}/common"

source "${COMMON_DIR}/config.sh"
source "${COMMON_DIR}/utils.sh"

TARGET_DATE="${1:-$(date -u +%Y-%m-%d)}"

print_header "Feature Engineering Pipeline Monitor"

# Ensure dependencies
if ! check_service_running "minio"; then
    log_error "MinIO is not running - start Level 0 first."
    exit 1
fi

if ! check_service_running "redis"; then
    log_error "Redis is not running - start Level 0 first."
    exit 1
fi

docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true

# Step 1: Check Silver data
log_info "Step 1: Checking Silver data availability for ${TARGET_DATE}"
SILVER_PATH="myminio/clinical-mlops/processed/patient_vitals_stream/processing_date=${TARGET_DATE}/"
if ! docker exec minio mc ls "${SILVER_PATH}" --recursive >/dev/null 2>&1; then
    log_error "No silver data found for ${TARGET_DATE} in ${SILVER_PATH}"
    echo ""
    echo "Suggestions:"
    echo "  1. Wait for streaming processors to populate silver data."
    echo "  2. Verify Level 2 services: spark-streaming, spark-batch, kafka producer/consumer."
    exit 1
fi
log_success "Silver data exists for ${TARGET_DATE}"
echo ""

# Step 2: Optionally run feature engineering job
log_info "Step 2: Running feature engineering job for ${TARGET_DATE}"
docker compose --profile features run --rm \
    -e PROCESS_DATE="${TARGET_DATE}" \
    feature-engineering
log_success "Feature engineering job completed"
echo ""

# Step 3: Verify offline feature store
log_info "Step 3: Verifying offline feature store"
FEATURE_PATH="myminio/clinical-mlops/features/offline/date=${TARGET_DATE}/"
if docker exec minio mc ls "${FEATURE_PATH}" --recursive >/dev/null 2>&1; then
    log_success "Offline features stored under ${FEATURE_PATH}"
else
    log_error "No offline features found at ${FEATURE_PATH}"
    exit 1
fi
echo ""

# Step 4: Verify online feature store (Redis)
log_info "Step 4: Verifying online feature store (Redis)"
PATIENT_COUNT=$(docker exec redis redis-cli --raw KEYS "patient:*:features" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "${PATIENT_COUNT:-0}" -gt 0 ]; then
    log_success "Redis contains ${PATIENT_COUNT} patient feature records"
else
    log_error "No patient feature keys found in Redis"
    exit 1
fi
echo ""

# Step 5: Check metadata file
log_info "Step 5: Checking feature metadata file"
METADATA_FILE="${ROOT_DIR}/../data/feature_metadata.json"
if [ -f "${METADATA_FILE}" ]; then
    FEATURE_COUNT=$(jq '.feature_count' "${METADATA_FILE}" 2>/dev/null || echo "unknown")
    log_success "Metadata file present (${FEATURE_COUNT} features)"
    jq '.by_source' "${METADATA_FILE}" 2>/dev/null || true
else
    log_error "Metadata file not found at ${METADATA_FILE}"
    exit 1
fi

echo ""
print_header "Feature Engineering Pipeline ✅"
log_success "All checks passed for ${TARGET_DATE}"
