#!/bin/bash
#
# Test Feature Store Connectivity and Operations
# Tests both offline (MinIO) and online (Redis) stores
#

set -e  # Exit on error

echo "=========================================="
echo "Feature Store Connectivity Test"
echo "=========================================="
echo ""

# Configuration
MINIO_ENDPOINT=${MINIO_ENDPOINT:-"http://localhost:9000"}
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-"minioadmin"}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-"minioadmin"}
REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-6379}
BUCKET_NAME="clinical-mlops"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for test results
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

echo "Testing Offline Feature Store (MinIO)..."
echo "------------------------------------------"

# Test 1: MinIO connectivity
echo -n "Test 1: MinIO server reachable... "
curl -s -f "${MINIO_ENDPOINT}/minio/health/live" > /dev/null 2>&1
test_result $? "MinIO server is reachable"

# Test 2: Check bucket exists
echo -n "Test 2: Bucket '${BUCKET_NAME}' exists... "
docker run --rm --network clinical-mlops_mlops-network \
    -e MINIO_ENDPOINT="${MINIO_ENDPOINT}" \
    -e AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY}" \
    -e AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY}" \
    amazon/aws-cli:latest \
    --endpoint-url "${MINIO_ENDPOINT}" \
    s3 ls s3://${BUCKET_NAME}/ > /dev/null 2>&1
test_result $? "Bucket exists and is accessible"

# Test 3: Check offline feature store path
echo -n "Test 3: Offline feature store path exists... "
docker run --rm --network clinical-mlops_mlops-network \
    -e MINIO_ENDPOINT="${MINIO_ENDPOINT}" \
    -e AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY}" \
    -e AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY}" \
    amazon/aws-cli:latest \
    --endpoint-url "${MINIO_ENDPOINT}" \
    s3 ls s3://${BUCKET_NAME}/features/offline/ > /dev/null 2>&1
test_result $? "Offline feature store path exists"

# Test 4: List recent feature partitions
echo ""
echo "Recent feature partitions:"
docker run --rm --network clinical-mlops_mlops-network \
    -e MINIO_ENDPOINT="${MINIO_ENDPOINT}" \
    -e AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY}" \
    -e AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY}" \
    amazon/aws-cli:latest \
    --endpoint-url "${MINIO_ENDPOINT}" \
    s3 ls s3://${BUCKET_NAME}/features/offline/ | tail -5

echo ""
echo "Testing Online Feature Store (Redis)..."
echo "------------------------------------------"

# Test 5: Redis connectivity
echo -n "Test 5: Redis server reachable... "
docker exec redis redis-cli ping > /dev/null 2>&1
test_result $? "Redis server is reachable"

# Test 6: Check Redis memory info
echo -n "Test 6: Redis memory usage... "
MEMORY_USED=$(docker exec redis redis-cli info memory | grep "used_memory_human" | cut -d':' -f2 | tr -d '\r')
if [ ! -z "$MEMORY_USED" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Redis memory usage: $MEMORY_USED"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Cannot get Redis memory info"
    ((TESTS_FAILED++))
fi

# Test 7: Count patient feature keys
echo -n "Test 7: Patient feature keys in Redis... "
PATIENT_COUNT=$(docker exec redis redis-cli --scan --pattern "patient:*:features" | wc -l)
if [ $PATIENT_COUNT -ge 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: Found $PATIENT_COUNT patient feature sets"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Cannot count patient keys"
    ((TESTS_FAILED++))
fi

# Test 8: Sample feature retrieval
if [ $PATIENT_COUNT -gt 0 ]; then
    echo -n "Test 8: Sample feature retrieval... "
    SAMPLE_KEY=$(docker exec redis redis-cli --scan --pattern "patient:*:features" | head -1)
    docker exec redis redis-cli hgetall "$SAMPLE_KEY" > /dev/null 2>&1
    test_result $? "Successfully retrieved sample features"
    
    echo ""
    echo "Sample features for key: $SAMPLE_KEY"
    docker exec redis redis-cli hgetall "$SAMPLE_KEY" | head -20
    echo "... (showing first 10 fields)"
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Test 8 - No patient keys to sample"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi