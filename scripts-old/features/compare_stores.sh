#!/bin/bash

echo "=== CLINICAL FEATURE STORE STATUS ==="
echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

# Set alias quietly
docker compose exec -T minio mc alias set myminio http://localhost:9000 minioadmin minioadmin 2>/dev/null

echo "📊 OFFLINE STORE (MinIO - Historical Data)"
echo "==========================================="

echo ""
echo "Raw Data (Bronze Layer):"
echo "----------------------------------------"
RAW_COUNT=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/raw/ 2>/dev/null | grep "date=2025-10-24" | wc -l | tr -d ' ')
if [ "${RAW_COUNT:-0}" -gt 0 ]; then
    echo "Patient Vitals:"
    docker compose exec -T minio mc ls myminio/clinical-mlops/raw/patient_vitals/date=2025-10-24/ 2>/dev/null | head -3
    echo ""
    echo "Lab Results:"
    docker compose exec -T minio mc ls myminio/clinical-mlops/raw/lab_results/date=2025-10-24/ 2>/dev/null | head -3
    echo ""
    echo "Medications:"
    docker compose exec -T minio mc ls myminio/clinical-mlops/raw/medications/date=2025-10-24/ 2>/dev/null | head -3
    echo ""
    echo "Adverse Events:"
    docker compose exec -T minio mc ls myminio/clinical-mlops/raw/adverse_events/date=2025-10-24/ 2>/dev/null | head -3
    echo ""
    docker compose exec -T minio mc du myminio/clinical-mlops/raw/ 2>/dev/null
    echo "Total files: $RAW_COUNT"
else
    echo "No data for 2025-10-24"
fi

echo ""
echo "Processed Data (Silver Layer):"
echo "----------------------------------------"
PROC_VITALS=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/processed/patient_vitals_stream/processing_date=2025-10-24/ 2>/dev/null | wc -l | tr -d ' ')
PROC_LABS=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/processed/lab_results/date=2025-10-24/ 2>/dev/null | wc -l | tr -d ' ')
PROC_MEDS=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/processed/medications/date=2025-10-24/ 2>/dev/null | wc -l | tr -d ' ')
PROC_AE=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/processed/adverse_events_stream/processing_date=2025-10-24/ 2>/dev/null | wc -l | tr -d ' ')

echo "Patient Vitals: ${PROC_VITALS:-0} files"
echo "Lab Results: ${PROC_LABS:-0} files"
echo "Medications: ${PROC_MEDS:-0} files"
echo "Adverse Events: ${PROC_AE:-0} files"
echo ""
docker compose exec -T minio mc du myminio/clinical-mlops/processed/ 2>/dev/null

echo ""
echo "Feature Store (Gold Layer):"
echo "----------------------------------------"
FEAT_COUNT=$(docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/features/offline/date=2025-10-24/ 2>/dev/null | wc -l | tr -d ' ')
if [ "${FEAT_COUNT:-0}" -gt 0 ]; then
    docker compose exec -T minio mc ls --recursive myminio/clinical-mlops/features/offline/date=2025-10-24/ 2>/dev/null | head -5
    docker compose exec -T minio mc du myminio/clinical-mlops/features/offline/date=2025-10-24/ 2>/dev/null
    echo "Files: $FEAT_COUNT"
else
    echo "⚠ No feature data - run feature engineering pipeline"
fi

echo ""
echo "⚡ ONLINE STORE (Redis - Real-time Features)"
echo "============================================="
TOTAL_PATIENTS=$(docker exec redis redis-cli --raw KEYS "patient:*:features" 2>/dev/null | wc -l | tr -d ' ')
echo "Total patients: ${TOTAL_PATIENTS:-0}"

if [ "${TOTAL_PATIENTS:-0}" -gt 0 ]; then
    SAMPLE_PATIENT=$(docker exec redis redis-cli --raw KEYS "patient:*:features" 2>/dev/null | head -1)
    echo "Sample patient: $SAMPLE_PATIENT"
    
    FEATURE_COUNT=$(docker exec redis redis-cli HLEN "$SAMPLE_PATIENT" 2>/dev/null)
    echo "Features per patient: ${FEATURE_COUNT:-0}"
    
    echo ""
    echo "Redis Memory:"
    docker exec redis redis-cli info memory 2>/dev/null | grep -E "used_memory_human" | head -1
    
    echo ""
    echo "Sample features:"
    docker exec redis redis-cli HGETALL "$SAMPLE_PATIENT" 2>/dev/null | head -10
else
    echo "⚠ No patient data in Redis"
fi

echo ""
echo "✅ STATUS SUMMARY"
echo "================="
echo "Bronze (Raw): $RAW_COUNT files"
echo "Silver (Processed): ${PROC_VITALS:-0} vitals, ${PROC_LABS:-0} labs, ${PROC_MEDS:-0} meds, ${PROC_AE:-0} events"
echo "Gold (Features): ${FEAT_COUNT:-0} files"
echo "Online (Redis): ${TOTAL_PATIENTS:-0} patients"