#!/bin/bash
# Data pipeline health check (Kafka → MinIO → Spark only)

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# =============================================================================
# 1. CONTAINER STATUS
# =============================================================================

print_header "1. Container Status"

check_container() {
    local container=$1
    
    if docker ps --filter "name=^${container}$" --format "{{.Names}}" | grep -q "^${container}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" = "running" ]; then
            print_success "$container is running"
            return 0
        else
            print_error "$container exists but not running (status: $status)"
            return 1
        fi
    else
        print_error "$container is not running"
        return 1
    fi
}

echo "Message Queue:"
check_container "zookeeper"
check_container "kafka"

echo ""
echo "Storage:"
check_container "minio"
# check_container "minio-setup"

echo ""
echo "Data Pipeline:"
check_container "kafka-producer"
check_container "kafka-consumer"

echo ""
echo "Spark Cluster:"
check_container "spark-master"
check_container "spark-worker"
check_container "spark-streaming"
check_container "spark-batch"

# =============================================================================
# 2. KAFKA HEALTH
# =============================================================================

print_header "2. Kafka Health & Topics"

# Wait a moment for Kafka to be ready
sleep 2

echo "Checking Kafka topics..."
TOPICS=$(docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null)

if [ $? -eq 0 ]; then
    print_success "Kafka is responding"
    echo ""
    echo "Topics found:"
    echo "$TOPICS" | while read topic; do
        if [ -n "$topic" ]; then
            echo "  • $topic"
        fi
    done
    
    # Check if our topics exist
    echo ""
    for topic in "patient-vitals" "lab-results" "medications" "adverse-events"; do
        if echo "$TOPICS" | grep -q "^${topic}$"; then
            print_success "Topic exists: $topic"
        else
            print_warning "Topic missing: $topic (will be auto-created on first message)"
        fi
    done
else
    print_error "Cannot connect to Kafka"
fi

# =============================================================================
# 3. KAFKA PRODUCER CHECK
# =============================================================================

print_header "3. Kafka Producer (Data Generation)"

if docker ps --filter "name=kafka-producer" --format "{{.Names}}" | grep -q "kafka-producer"; then
    print_success "Producer container is running"
    
    echo ""
    echo "Recent producer logs:"
    echo "─────────────────────────────────────"
    docker logs kafka-producer --tail 10 2>&1
    echo "─────────────────────────────────────"
    
    # Check if it's producing
    MESSAGES_SENT=$(docker logs kafka-producer 2>&1 | grep -c "Sent\|messages" || echo "0")
    
    if [ "$MESSAGES_SENT" -gt 0 ]; then
        echo ""
        print_success "Producer is generating messages ($MESSAGES_SENT log entries)"
    else
        echo ""
        print_warning "No message generation detected in logs"
        print_info "Wait 10 seconds and check again, or view live: docker logs -f kafka-producer"
    fi
else
    print_error "Producer is not running"
fi

# =============================================================================
# 4. KAFKA MESSAGE VERIFICATION
# =============================================================================

print_header "4. Kafka Messages (Sampling)"

echo "Attempting to read messages from topics..."
echo ""

check_topic_messages() {
    local topic=$1
    echo "Checking: $topic"
    
    local msg_count=$(timeout 3 docker exec kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic "$topic" \
        --from-beginning \
        --max-messages 3 \
        2>/dev/null | wc -l)
    
    if [ "$msg_count" -gt 0 ]; then
        print_success "  Found $msg_count messages"
        
        # Show one sample
        echo "  Sample message:"
        timeout 3 docker exec kafka kafka-console-consumer \
            --bootstrap-server localhost:9092 \
            --topic "$topic" \
            --from-beginning \
            --max-messages 1 \
            2>/dev/null | head -1 | jq -c '.' 2>/dev/null | sed 's/^/    /'
    else
        print_warning "  No messages found (yet)"
    fi
    echo ""
}

check_topic_messages "patient-vitals"
check_topic_messages "lab-results"
check_topic_messages "medications"
check_topic_messages "adverse-events"

# =============================================================================
# 5. KAFKA CONSUMER CHECK
# =============================================================================

print_header "5. Kafka Consumer (Bronze Layer Ingestion)"

if docker ps --filter "name=kafka-consumer" --format "{{.Names}}" | grep -q "kafka-consumer"; then
    print_success "Consumer container is running"
    
    echo ""
    echo "Recent consumer logs:"
    echo "─────────────────────────────────────"
    docker logs kafka-consumer --tail 15 2>&1
    echo "─────────────────────────────────────"
    
    # Check if consuming
    BATCHES_WRITTEN=$(docker logs kafka-consumer 2>&1 | grep -c "Wrote\|Flushed\|batch" || echo "0")
    
    if [ "$BATCHES_WRITTEN" -gt 0 ]; then
        echo ""
        print_success "Consumer is processing and writing batches ($BATCHES_WRITTEN operations)"
    else
        echo ""
        print_warning "No batch writes detected in logs"
        print_info "Consumer may be accumulating messages (batches every 30s or 1000 msgs)"
    fi
else
    print_error "Consumer is not running"
fi

# =============================================================================
# 6. MINIO BRONZE LAYER (RAW DATA)
# =============================================================================

print_header "6. MinIO Bronze Layer (Raw Data)"

echo "Configuring MinIO client..."
docker run --rm --network clinical-trials-service_mlops-network \
    --entrypoint /bin/sh \
    minio/mc:latest \
    -c "mc alias set myminio http://minio:9000 minioadmin minioadmin" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "MinIO is accessible"
else
    print_error "Cannot connect to MinIO"
    exit 1
fi

echo ""
echo "Checking raw data directories..."

check_bronze_data() {
    local topic=$1
    local path="clinical-mlops/raw/${topic}/"
    
    local file_count=$(docker run --rm --network clinical-trials-service_mlops-network \
        --entrypoint /bin/sh \
        minio/mc:latest \
        -c "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>/dev/null && \
            mc ls --recursive myminio/$path 2>/dev/null | wc -l")
    
    if [ "$file_count" -gt 0 ]; then
        print_success "$topic: $file_count files"
        
        # Get latest file info
        local latest=$(docker run --rm --network clinical-trials-service_mlops-network \
            --entrypoint /bin/sh \
            minio/mc:latest \
            -c "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>/dev/null && \
                mc ls --recursive myminio/$path 2>/dev/null | tail -1 | awk '{print \$4, \$5, \$6}'")
        
        print_info "  Latest: $latest"
    else
        print_warning "$topic: No files yet"
    fi
}

check_bronze_data "patient_vitals"
check_bronze_data "lab_results"
check_bronze_data "medications"
check_bronze_data "adverse_events"

# =============================================================================
# 7. SPARK CLUSTER STATUS
# =============================================================================

print_header "7. Spark Cluster Status"

# Check Spark Master
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    print_success "Spark Master UI accessible at http://localhost:8080"
    
    # Try to get worker count
    WORKER_INFO=$(curl -s http://localhost:8080 2>/dev/null | grep -o "Workers ([0-9]*)" | head -1)
    if [ -n "$WORKER_INFO" ]; then
        print_info "  $WORKER_INFO"
    fi
else
    print_error "Cannot access Spark Master UI"
fi

echo ""

# Check worker
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    print_success "Spark Worker UI accessible at http://localhost:8081"
else
    print_warning "Cannot access Spark Worker UI"
fi

# =============================================================================
# 8. SPARK STREAMING STATUS
# =============================================================================

print_header "8. Spark Streaming (Real-time Processing)"

if docker ps --filter "name=spark-streaming" --format "{{.Names}}" | grep -q "spark-streaming"; then
    print_success "Spark Streaming container is running"
    
    echo ""
    echo "Recent streaming logs:"
    echo "─────────────────────────────────────"
    docker logs spark-streaming --tail 20 2>&1 | grep -v "WARN\|INFO org.apache" | tail -15
    echo "─────────────────────────────────────"
    
    # Check if processing
    PROCESSING=$(docker logs spark-streaming 2>&1 | grep -c "Processing\|Wrote\|stream started" || echo "0")
    
    if [ "$PROCESSING" -gt 0 ]; then
        echo ""
        print_success "Streaming is processing data ($PROCESSING log entries)"
    else
        echo ""
        print_warning "No processing activity detected"
        print_info "Streaming may be starting up or waiting for data"
    fi
else
    print_error "Spark Streaming is not running"
    print_info "Start with: docker compose up -d spark-streaming"
fi

# =============================================================================
# 9. MINIO SILVER LAYER (PROCESSED DATA)
# =============================================================================

print_header "9. MinIO Silver Layer (Processed Data)"

echo "Checking processed data directories..."

check_silver_data() {
    local name=$1
    local path="clinical-mlops/processed/${name}/"
    
    local file_count=$(docker run --rm --network clinical-trials-service_mlops-network \
        --entrypoint /bin/sh \
        minio/mc:latest \
        -c "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>/dev/null && \
            mc ls --recursive myminio/$path 2>/dev/null | wc -l")
    
    if [ "$file_count" -gt 0 ]; then
        print_success "$name: $file_count files"
    else
        print_warning "$name: No files (processing not started or no data yet)"
    fi
}

check_silver_data "patient_vitals_stream"
check_silver_data "adverse_events_stream"
check_silver_data "lab_results"
check_silver_data "medications"

# =============================================================================
# 10. DATA FLOW SUMMARY
# =============================================================================

print_header "10. Data Flow Summary"

# Count files in each layer
BRONZE_TOTAL=$(docker run --rm --network clinical-trials-service_mlops-network \
    --entrypoint /bin/sh \
    minio/mc:latest \
    -c "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>/dev/null && \
        mc ls --recursive myminio/clinical-mlops/raw/ 2>/dev/null | wc -l")

SILVER_TOTAL=$(docker run --rm --network clinical-trials-service_mlops-network \
    --entrypoint /bin/sh \
    minio/mc:latest \
    -c "mc alias set myminio http://minio:9000 minioadmin minioadmin 2>/dev/null && \
        mc ls --recursive myminio/clinical-mlops/processed/ 2>/dev/null | wc -l")

echo "Pipeline Status:"
echo ""
echo "  Bronze Layer (raw):      $BRONZE_TOTAL files"
echo "  Silver Layer (processed): $SILVER_TOTAL files"
echo ""

if [ "$BRONZE_TOTAL" -gt 0 ] && [ "$SILVER_TOTAL" -gt 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ PIPELINE IS HEALTHY - DATA IS FLOWING${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
elif [ "$BRONZE_TOTAL" -gt 0 ] && [ "$SILVER_TOTAL" -eq 0 ]; then
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠️  DATA IN BRONZE, WAITING FOR SPARK    ${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    echo ""
    print_info "Spark Streaming needs time to start processing"
    print_info "Check: docker logs -f spark-streaming"
elif [ "$BRONZE_TOTAL" -eq 0 ]; then
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}❌ NO DATA IN BRONZE - CHECK KAFKA       ${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo ""
    print_info "Data is not reaching MinIO"
    print_info "Check: docker logs -f kafka-producer kafka-consumer"
else
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⏳ PIPELINE STARTING UP...              ${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
fi

echo ""
echo "Service URLs:"
echo "  • MinIO Console:  http://localhost:9001 (minioadmin/minioadmin)"
echo "  • Spark Master:   http://localhost:8080"
echo "  • Spark Worker:   http://localhost:8081"
echo "  • Kafka UI:       http://localhost:8090 (if started)"
echo ""


# Quick health check for all services

echo "🔍 Checking service health..."
echo ""

# Check HTTP endpoints
check_url() {
    url=$1
    name=$2
    if curl -f -s "$url" > /dev/null; then
        echo "✅ $name - OK"
    else
        echo "❌ $name - FAILED"
    fi
}

check_url "http://localhost:9001/minio/health/live" "MinIO"
check_url "http://localhost:8090" "Kafka UI"
check_url "http://localhost:8080" "Spark Master"
check_url "http://localhost:5000/health" "MLflow"
check_url "http://localhost:9090/-/healthy" "Prometheus"
check_url "http://localhost:3000/api/health" "Grafana"
check_url "http://localhost:5601/api/status" "OpenSearch Dashboards"

echo ""
echo "🔍 Checking Kafka..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1 && echo "✅ Kafka - OK" || echo "❌ Kafka - FAILED"

echo ""
echo "🔍 Checking containers..."
docker ps --format "{{.Names}}\t{{.Status}}" | grep -E "(kafka-producer|kafka-consumer)" | while read line; do
    echo "  $line"
done