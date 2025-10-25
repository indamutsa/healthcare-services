#!/bin/bash
#
# Compare Feature Stores - Offline (MinIO) and Online (Redis)
#

set -euo pipefail

FEATURE_ENGINEERING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "${FEATURE_ENGINEERING_SCRIPT_DIR}/../common" && pwd)"

source "${COMMON_DIR}/config.sh"
source "${COMMON_DIR}/utils.sh"

TARGET_DATE="${1:-$(date -u +%Y-%m-%d)}"

print_header "Feature Store Status"
echo "Date (UTC): ${TARGET_DATE}"
echo ""

# Ensure dependencies are running
if ! check_service_running "minio"; then
    log_error "MinIO is not running. Start Level 0 before comparing stores."
    exit 1
fi

if ! check_service_running "redis"; then
    log_error "Redis is not running. Start Level 0 before comparing stores."
    exit 1
fi

# Configure MinIO alias (ignore errors if already configured)
docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true

echo "📊 OFFLINE STORE (MinIO - Historical Data)"
echo "==========================================="
echo ""

echo "Raw Data (Bronze Layer):"
echo "----------------------------------------"
RAW_COUNT=$(docker exec minio mc ls myminio/clinical-mlops/raw/ --recursive 2>/dev/null | grep "date=${TARGET_DATE}" | wc -l | tr -d ' ' || echo "0")
if [ "${RAW_COUNT:-0}" -gt 0 ]; then
    for dataset in patient_vitals lab_results medications adverse_events; do
        echo "${dataset^}:"
        docker exec minio mc ls "myminio/clinical-mlops/raw/${dataset}/date=${TARGET_DATE}/" 2>/dev/null | head -5 || true
        echo ""
    done
    docker exec minio mc du myminio/clinical-mlops/raw/ 2>/dev/null || true
    echo "Total files: $RAW_COUNT"
else
    echo "⚠ No bronze data found for ${TARGET_DATE}"
fi

echo ""
echo "Processed Data (Silver Layer):"
echo "----------------------------------------"
declare -A SILVER_PATHS=(
    ["patient_vitals_stream"]="processed/patient_vitals_stream/processing_date=${TARGET_DATE}/"
    ["lab_results"]="processed/lab_results/date=${TARGET_DATE}/"
    ["medications"]="processed/medications/date=${TARGET_DATE}/"
    ["adverse_events_stream"]="processed/adverse_events_stream/processing_date=${TARGET_DATE}/"
)
SILVER_KEYS=(patient_vitals_stream lab_results medications adverse_events_stream)

for key in "${SILVER_KEYS[@]}"; do
    COUNT=$(docker exec minio mc ls "myminio/clinical-mlops/${SILVER_PATHS[$key]}" --recursive 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    printf "%-22s: %s files\n" "${key//_/ }" "${COUNT}"
done
echo ""
docker exec minio mc du myminio/clinical-mlops/processed/ 2>/dev/null || true

echo ""
echo "Feature Store (Gold Layer):"
echo "----------------------------------------"
FEATURE_PATH="myminio/clinical-mlops/features/offline/date=${TARGET_DATE}/"
FEATURE_COUNT=$(docker exec minio mc ls "${FEATURE_PATH}" --recursive 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "${FEATURE_COUNT:-0}" -gt 0 ]; then
    docker exec minio mc ls "${FEATURE_PATH}" --recursive 2>/dev/null | head -10 || true
    docker exec minio mc du "${FEATURE_PATH}" 2>/dev/null || true
    echo "Files: $FEATURE_COUNT"
else
    echo "⚠ No offline feature data found. Run the feature engineering pipeline."
fi

echo ""
echo "⚡ ONLINE STORE (Redis - Real-time Features)"
echo "============================================="
TOTAL_PATIENTS=$(docker exec redis redis-cli --raw KEYS "patient:*:features" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
echo "Total patients: ${TOTAL_PATIENTS:-0}"

if [ "${TOTAL_PATIENTS:-0}" -gt 0 ]; then
    SAMPLE_PATIENT=$(docker exec redis redis-cli --raw KEYS "patient:*:features" 2>/dev/null | head -1)
    echo "Sample patient key: ${SAMPLE_PATIENT}"

    FEATURE_COUNT=$(docker exec redis redis-cli HLEN "${SAMPLE_PATIENT}" 2>/dev/null || echo "0")
    echo "Features per patient: ${FEATURE_COUNT}"

    echo ""
    echo "Redis Memory:"
    docker exec redis redis-cli info memory 2>/dev/null | grep -E "used_memory_human" | head -1 || true

    echo ""
    echo "Sample features:"
    docker exec redis redis-cli HGETALL "${SAMPLE_PATIENT}" 2>/dev/null | head -20 || true
else
    echo "⚠ No online feature data found."
fi

echo ""
echo "✅ STATUS SUMMARY"
echo "================="
echo "Bronze (Raw):      ${RAW_COUNT:-0} files"
echo "Silver (Processed):"
for key in "${SILVER_KEYS[@]}"; do
    COUNT=$(docker exec minio mc ls "myminio/clinical-mlops/${SILVER_PATHS[$key]}" --recursive 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    printf "  - %-18s %s files\n" "${key//_/ }" "${COUNT}"
done
echo "Gold (Features):   ${FEATURE_COUNT:-0} files"
echo "Online (Redis):    ${TOTAL_PATIENTS:-0} patients"
