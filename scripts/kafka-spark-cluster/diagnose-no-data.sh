#!/bin/bash
# Diagnose why data is not flowing

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_header "🔍 Diagnosing Data Flow Issues"

# =============================================================================
# 1. Check Kafka Producer
# =============================================================================

echo "1. Checking Kafka Producer..."
echo ""

if docker ps | grep -q kafka-producer; then
    echo "✓ Kafka Producer is running"
    
    # Check logs
    echo ""
    echo "Recent producer logs:"
    docker logs kafka-producer --tail 20 2>&1
    
    # Check if it's actually producing
    PRODUCING=$(docker logs kafka-producer 2>&1 | tail -50 | grep -c "Sent" || echo "0")
    
    if [ "$PRODUCING" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Producer is sending messages${NC}"
    else
        echo ""
        echo -e "${RED}✗ Producer is NOT sending messages${NC}"
        echo ""
        echo "Possible issues:"
        echo "  - Kafka connection failed"
        echo "  - Producer crashed during initialization"
        echo ""
        echo "Try:"
        echo "  docker compose restart kafka-producer"
        echo "  docker compose logs -f kafka-producer"
    fi
else
    echo -e "${RED}✗ Kafka Producer is not running${NC}"
    echo ""
    echo "Start it with:"
    echo "  docker compose up -d kafka-producer"
fi

# =============================================================================
# 2. Check Kafka Topics
# =============================================================================

print_header "2. Checking Kafka Topics"

echo "Listing all topics..."
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>&1

echo ""
echo "Checking message count on patient-vitals topic..."
timeout 5 docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic patient-vitals \
    --from-beginning \
    --max-messages 5 2>&1 || echo "(timeout or no messages)"

# =============================================================================
# 3. Check Kafka Consumer
# =============================================================================

print_header "3. Checking Kafka Consumer"

if docker ps | grep -q kafka-consumer; then
    echo "✓ Kafka Consumer is running"
    
    echo ""
    echo "Recent consumer logs:"
    docker logs kafka-consumer --tail 30 2>&1
    
    # Check if consuming
    CONSUMING=$(docker logs kafka-consumer 2>&1 | tail -50 | grep -c "Consumed\|batch" || echo "0")
    
    if [ "$CONSUMING" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Consumer is processing messages${NC}"
    else
        echo ""
        echo -e "${RED}✗ Consumer is NOT processing messages${NC}"
        echo ""
        echo "Possible issues:"
        echo "  - No messages in Kafka topics"
        echo "  - Consumer group offset issue"
        echo "  - S3/MinIO connection failed"
        echo ""
        echo "Try:"
        echo "  docker compose restart kafka-consumer"
        echo "  docker compose logs -f kafka-consumer"
    fi
else
    echo -e "${RED}✗ Kafka Consumer is not running${NC}"
    echo ""
    echo "Start it with:"
    echo "  docker compose up -d kafka-consumer"
fi

# =============================================================================
# 4. Check MinIO Connection
# =============================================================================

print_header "4. Checking MinIO Connection"

if curl -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
    echo "✓ MinIO is accessible"
    
    # Check if consumer can write
    echo ""
    echo "Testing S3 write access..."
    
    docker run --rm --network clinical-trials-service_mlops-network \
        --entrypoint /bin/sh \
        minio/mc:latest \
        -c "mc alias set myminio http://minio:9000 minioadmin minioadmin && \
            echo 'test' | mc pipe myminio/clinical-mlops/test.txt && \
            echo '✓ Write test successful' && \
            mc rm myminio/clinical-mlops/test.txt"
else
    echo -e "${RED}✗ Cannot connect to MinIO${NC}"
    echo ""
    echo "Check if MinIO is running:"
    echo "  docker compose ps minio"
    echo "  docker compose logs minio"
fi

# =============================================================================
# 5. Network Check
# =============================================================================

print_header "5. Checking Network Connectivity"

echo "Testing connectivity between services..."

# Producer -> Kafka
echo ""
echo "Producer -> Kafka:"
docker exec kafka-producer ping -c 1 kafka > /dev/null 2>&1 && \
    echo "  ✓ Can reach Kafka" || echo "  ✗ Cannot reach Kafka"

# Consumer -> Kafka
echo "Consumer -> Kafka:"
docker exec kafka-consumer ping -c 1 kafka > /dev/null 2>&1 && \
    echo "  ✓ Can reach Kafka" || echo "  ✗ Cannot reach Kafka"

# Consumer -> MinIO
echo "Consumer -> MinIO:"
docker exec kafka-consumer ping -c 1 minio > /dev/null 2>&1 && \
    echo "  ✓ Can reach MinIO" || echo "  ✗ Cannot reach MinIO"

# =============================================================================
# 6. Recommendations
# =============================================================================

print_header "6. Recommended Actions"

echo "If still no data, try these steps in order:"
echo ""
echo "1. Restart Kafka ecosystem:"
echo "   docker compose restart zookeeper kafka"
echo "   sleep 30  # Wait for Kafka to stabilize"
echo ""
echo "2. Restart producers and consumers:"
echo "   docker compose restart kafka-producer kafka-consumer"
echo ""
echo "3. Watch logs in real-time:"
echo "   docker compose logs -f kafka-producer kafka-consumer"
echo ""
echo "4. Nuclear option (fresh start):"
echo "   docker compose down -v  # ⚠️  This deletes all data!"
echo "   docker compose up -d"
echo ""
echo "5. Check for specific errors:"
echo "   docker compose logs kafka-producer | grep -i error"
echo "   docker compose logs kafka-consumer | grep -i error"
echo ""