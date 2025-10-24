#!/bin/bash

# Complete End-to-End Test of Clinical MLOps Pipeline

set -e

echo "============================================================"
echo "Clinical MLOps - End-to-End Pipeline Test"
echo "============================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TODAY=$(date -u +%Y-%m-%d)

echo -e "\n${BLUE}Testing Date: $TODAY${NC}\n"

# Test 1: Infrastructure
echo -e "${YELLOW}■ Test 1: Infrastructure Services${NC}"
echo "------------------------------------------------------------"

services="minio kafka redis spark-master spark-worker"
for service in $services; do
    if docker-compose ps | grep -q "$service.*Up"; then
        echo -e "  ${GREEN}✓${NC} $service"
    else
        echo -e "  ${RED}✗${NC} $service (not running)"
        exit 1
    fi
done

# Test 2: Data Generation
echo -e "\n${YELLOW}■ Test 2: Data Generation (Kafka)${NC}"
echo "------------------------------------------------------------"

if docker-compose ps | grep -q "kafka-producer.*Up"; then
    echo -e "  ${GREEN}✓${NC} Kafka producer running"
    
    # Check topic messages
    TOPIC_COUNT=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic patient-vitals \
        --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum}')
    
    echo -e "  ${GREEN}✓${NC} Messages in patient-vitals: $TOPIC_COUNT"
else
    echo -e "  ${RED}✗${NC} Kafka producer not running"
    exit 1
fi

# Test 3: Data Ingestion
echo -e "\n${YELLOW}■ Test 3: Data Ingestion (Bronze Layer)${NC}"
echo "------------------------------------------------------------"

BRONZE_FILES=$(docker run --rm --network clinical-mlops_mlops-network \
    minio/mc ls --recursive myminio/clinical-mlops/raw/ 2>/dev/null | wc -l)

if [ "$BRONZE_FILES" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Bronze layer files: $BRONZE_FILES"
else
    echo -e "  ${RED}✗${NC} No bronze layer data"
    exit 1
fi

# Test 4: Data Processing
echo -e "\n${YELLOW}■ Test 4: Data Processing (Silver Layer)${NC}"
echo "------------------------------------------------------------"

# Wait for streaming processor to create data
echo "  Waiting for silver data (up to 60 seconds)..."
for i in {1..12}; do
    SILVER_EXISTS=$(docker run --rm --network clinical-mlops_mlops-network \
        minio/mc ls myminio/clinical-mlops/processed/patient_vitals_stream/processing_date=$TODAY/ 2>/dev/null | wc -l)
    
    if [ "$SILVER_EXISTS" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Silver layer data exists"
        break
    fi
    
    if [ $i -eq 12 ]; then
        echo -e "  ${RED}✗${NC} No silver data after 60 seconds"
        echo "  Check spark-streaming logs: docker-compose logs spark-streaming"
        exit 1
    fi
    
    sleep 5
done

# Test 5: Feature Engineering
echo -e "\n${YELLOW}■ Test 5: Feature Engineering${NC}"
echo "------------------------------------------------------------"

echo "  Running feature engineering pipeline..."
docker-compose --profile feature-engineering run --rm \
    -e PROCESS_DATE=$TODAY \
    feature-engineering > /tmp/feature_eng.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Feature engineering completed"
else
    echo -e "  ${RED}✗${NC} Feature engineering failed"
    cat /tmp/feature_eng.log
    exit 1
fi

# Test 6: Offline Feature Store
echo -e "\n${YELLOW}■ Test 6: Offline Feature Store (MinIO)${NC}"
echo "------------------------------------------------------------"

OFFLINE_FILES=$(docker run --rm --network clinical-mlops_mlops-network \
    minio/mc ls myminio/clinical-mlops/features/offline/date=$TODAY/ 2>/dev/null | wc -l)

if [ "$OFFLINE_FILES" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Offline store populated: $OFFLINE_FILES files"
    
    SIZE=$(docker run --rm --network clinical-mlops_mlops-network \
        minio/mc du myminio/clinical-mlops/features/offline/date=$TODAY/ 2>/dev/null)
    echo -e "  ${GREEN}✓${NC} Total size: $SIZE"
else
    echo -e "  ${RED}✗${NC} No offline store data"
    exit 1
fi

# Test 7: Online Feature Store
echo -e "\n${YELLOW}■ Test 7: Online Feature Store (Redis)${NC}"
echo "------------------------------------------------------------"

PATIENT_COUNT=$(docker exec redis redis-cli KEYS "patient:*:features" 2>/dev/null | wc -l)

if [ "$PATIENT_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Patients in online store: $PATIENT_COUNT"
    
    # Get sample patient
    SAMPLE=$(docker exec redis redis-cli KEYS "patient:*:features" 2>/dev/null | head -n 1 | tr -d '\r')
    FEATURE_COUNT=$(docker exec redis redis-cli HLEN "$SAMPLE" 2>/dev/null)
    echo -e "  ${GREEN}✓${NC} Features per patient: $FEATURE_COUNT"
else
    echo -e "  ${RED}✗${NC} No patients in online store"
    exit 1
fi

# Test 8: Feature Metadata
echo -e "\n${YELLOW}■ Test 8: Feature Metadata${NC}"
echo "------------------------------------------------------------"

if [ -f "./data/feature_metadata.json" ]; then
    TOTAL_FEATURES=$(jq '.feature_count' ./data/feature_metadata.json)
    echo -e "  ${GREEN}✓${NC} Metadata file exists"
    echo -e "  ${GREEN}✓${NC} Total features: $TOTAL_FEATURES"
    
    echo ""
    echo "  Features by source:"
    jq -r '.by_source | to_entries | .[] | "    \(.key): \(.value)"' ./data/feature_metadata.json
else
    echo -e "  ${RED}✗${NC} Metadata file not found"
    exit 1
fi

# Final Summary
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "Pipeline Summary:"
echo "  Date: $TODAY"
echo "  Bronze files: $BRONZE_FILES"
echo "  Silver records: Available"
echo "  Features generated: $TOTAL_FEATURES"
echo "  Patients in online store: $PATIENT_COUNT"
echo ""
echo "Access Points:"
echo "  MinIO Console: http://localhost:9001"
echo "  Redis Insight: http://localhost:5540"
echo "  Spark UI: http://localhost:8080"
echo ""