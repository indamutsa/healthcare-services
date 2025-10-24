#!/bin/bash

# Test Feature Engineering Pipeline

set -e

echo "============================================================"
echo "Testing Feature Engineering Pipeline"
echo "============================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get today's date
TODAY=$(date -u +%Y-%m-%d)

echo -e "\n${YELLOW}Step 1: Check if Silver data exists${NC}"
echo "Date: $TODAY"

# Check MinIO for silver data
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls --recursive myminio/clinical-mlops/processed/patient_vitals_stream/processing_date=$TODAY/ 2>/dev/null || {
    echo -e "${RED}✗ No silver data found for $TODAY${NC}"
    echo ""
    echo "Solutions:"
    echo "1. Wait for streaming processor to generate data"
    echo "2. Check if producer and consumer are running:"
    echo "   docker-compose ps kafka-producer kafka-consumer spark-streaming"
    echo ""
    exit 1
}

echo -e "${GREEN}✓ Silver data exists${NC}"

echo -e "\n${YELLOW}Step 2: Run Feature Engineering${NC}"

# Run feature engineering
docker-compose --profile feature-engineering run --rm \
  -e PROCESS_DATE=$TODAY \
  feature-engineering

echo -e "\n${YELLOW}Step 3: Verify Offline Store${NC}"

# Check offline store
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls --recursive myminio/clinical-mlops/features/offline/date=$TODAY/ || {
    echo -e "${RED}✗ No features found in offline store${NC}"
    exit 1
}

echo -e "${GREEN}✓ Features written to offline store${NC}"

echo -e "\n${YELLOW}Step 4: Verify Online Store (Redis)${NC}"

# Check Redis
PATIENT_COUNT=$(docker exec redis redis-cli KEYS "patient:*:features" | wc -l)

if [ "$PATIENT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $PATIENT_COUNT patients in online store${NC}"
else
    echo -e "${RED}✗ No features found in online store${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 5: Check Metadata${NC}"

# Check metadata file
if [ -f "./data/feature_metadata.json" ]; then
    FEATURE_COUNT=$(jq '.feature_count' ./data/feature_metadata.json)
    echo -e "${GREEN}✓ Metadata file exists: $FEATURE_COUNT features${NC}"
    cat ./data/feature_metadata.json | jq '.by_source'
else
    echo -e "${RED}✗ Metadata file not found${NC}"
    exit 1
fi

echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
echo -e "${GREEN}============================================================${NC}"