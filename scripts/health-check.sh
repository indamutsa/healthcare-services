#!/bin/bash
#
# Pipeline Health Check - Validates all dependencies and data flow by level
#

# set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# --- Level Definitions (matching manage_pipeline.sh) ---
declare -A LEVEL_SERVICES
declare -A LEVEL_NAMES

# Level 0: Infrastructure
LEVEL_SERVICES[0]="minio minio-setup postgres-mlflow postgres-airflow redis redis-insight zookeeper kafka kafka-ui"
LEVEL_NAMES[0]="Infrastructure"

# Level 1: Data Ingestion
LEVEL_SERVICES[1]="kafka-producer kafka-consumer clinical-mq clinical-data-gateway lab-results-processor clinical-data-generator"
LEVEL_NAMES[1]="Data Ingestion"

# Level 2: Data Processing
LEVEL_SERVICES[2]="spark-master spark-worker spark-streaming spark-batch"
LEVEL_NAMES[2]="Data Processing"

# Level 3: Feature Engineering
LEVEL_SERVICES[3]="feature-engineering"
LEVEL_NAMES[3]="Feature Engineering"

# Level 4: ML Pipeline
LEVEL_SERVICES[4]="mlflow-server ml-training model-serving"
LEVEL_NAMES[4]="ML Pipeline"

# Level 5: Observability
LEVEL_SERVICES[5]="airflow-init airflow-webserver airflow-scheduler prometheus grafana monitoring-service opensearch opensearch-dashboards data-prepper filebeat"
LEVEL_NAMES[5]="Observability"

MAX_LEVEL=5

print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

print_level_header() {
    local level=$1
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Level $level: ${LEVEL_NAMES[$level]} Health${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check() {
    local test_name=$1
    local command=$2
    local is_warning=${3:-false}
    
    echo -n "  Testing: $test_name ... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$is_warning" = true ]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((CHECKS_WARNING++))
            return 1
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((CHECKS_FAILED++))
            return 1
        fi
    fi
}

check_service_running() {
    local service=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        return 0
    else
        return 1
    fi
}

check_minio_bucket() {
    local bucket_path=$1
    local description=$2
    local is_warning=${3:-false}
    
    # Use the minio container with proper alias configuration
    check "$description" \
        "docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 && docker exec minio mc ls myminio/$bucket_path 2>/dev/null | head -1" \
        "$is_warning"
}

check_level_0() {
    print_level_header 0
    
    check "MinIO server accessible" \
        "curl -sf http://localhost:9000/minio/health/live"
    
    check "MinIO setup completed" \
        "docker logs minio-setup 2>&1 | grep -q 'MinIO setup completed successfully'"
    
    check "MinIO client configured" \
        "docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin"
    
    check_minio_bucket "clinical-mlops" "MinIO clinical-mlops bucket exists"
    
    check "Kafka broker accessible" \
        "docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092"
    
    check "Redis server accessible" \
        "docker exec redis redis-cli ping"
    
    check "PostgreSQL (mlflow) accessible" \
        "docker exec postgres-mlflow pg_isready -U mlflow"
    
    check "PostgreSQL (airflow) accessible" \
        "docker exec postgres-airflow pg_isready -U airflow"
    
    check "Zookeeper running" \
        "docker exec zookeeper /bin/sh -c 'echo srvr | nc localhost 2181' | grep -q Mode"
        
    check "Kafka UI accessible" \
        "curl -sf http://localhost:8090" \
        true
        
    check "Redis Insight accessible" \
        "curl -sf http://localhost:5540" \
        true
}

check_level_1() {
    print_level_header 1
    
    check "Kafka producer running" \
        "check_service_running kafka-producer"
    
    check "Kafka consumer running" \
        "check_service_running kafka-consumer"
    
    check "Clinical MQ running" \
        "check_service_running clinical-mq" \
        true
    
    check "Clinical data gateway running" \
        "curl -sf http://localhost:8080/actuator/health"

    if check_service_running kafka-producer; then
        check "Kafka topics exist" \
            "docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep -q patient-vitals"
        
        check_minio_bucket "clinical-mlops/raw/" "Bronze data exists" true
    fi
}

check_level_2() {
    print_level_header 2
    
    check "Spark master running" \
        "check_service_running spark-master"
    
    check "Spark worker running" \
        "check_service_running spark-worker"
    
    check "Spark streaming running" \
        "check_service_running spark-streaming" \
        true
    
    check "Spark batch running" \
        "check_service_running spark-batch" \
        true

    if check_service_running spark-master; then
        check "Spark master accessible" \
            "curl -sf http://localhost:8080"
        
        check_minio_bucket "clinical-mlops/processed/" "Silver data exists" true
    fi
}

check_level_3() {
    print_level_header 3
    
    check "Feature engineering service running" \
        "check_service_running feature-engineering"

    if check_service_running feature-engineering; then
        check_minio_bucket "clinical-mlops/features/offline/" "Offline features exist" true
        
        check "Online features in Redis" \
            "docker exec redis redis-cli --scan --pattern 'patient:*:features' 2>/dev/null | head -1" \
            true
    fi
}

check_level_4() {
    print_level_header 4
    
    check "MLflow server accessible" \
        "curl -sf http://localhost:5000/health" \
        true
    
    check "Model serving API running" \
        "check_service_running model-serving"
    
    check "ML training service running" \
        "check_service_running ml-training" \
        true

    if check_service_running model-serving; then
        check "Model serving health endpoint" \
            "curl -sf http://localhost:8000/health" \
            true
    fi
    
    if check_service_running ml-training; then
        check_minio_bucket "mlflow-artifacts" "MLflow artifacts bucket exists" true
    fi
}

check_level_5() {
    print_level_header 5
    
    check "Prometheus running" \
        "check_service_running prometheus"
    
    check "Grafana running" \
        "check_service_running grafana"
    
    check "Airflow webserver running" \
        "check_service_running airflow-webserver"
    
    check "Airflow scheduler running" \
        "check_service_running airflow-scheduler" \
        true
    
    check "OpenSearch running" \
        "check_service_running opensearch" \
        true
    
    check "OpenSearch dashboards running" \
        "check_service_running opensearch-dashboards" \
        true

    if check_service_running prometheus; then
        check "Prometheus accessible" \
            "curl -sf http://localhost:9090/-/healthy"
    fi

    if check_service_running grafana; then
        check "Grafana accessible" \
            "curl -sf http://localhost:3000/api/health"
    fi
    
    if check_service_running airflow-webserver; then
        check "Airflow accessible" \
            "curl -sf http://localhost:8081/health" \
            true
    fi
}

check_data_flow() {
    print_header "Data Flow Validation"
    
    if check_service_running kafka-consumer || check_service_running spark-streaming; then
        echo "  Checking data flow through pipeline..."
        echo ""
        
        # Configure MinIO alias for counting
        docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1
        
        # Check Bronze layer
        BRONZE_COUNT=$(docker exec minio mc ls myminio/clinical-mlops/raw/ --recursive 2>/dev/null | wc -l || echo "0")
        echo "    Bronze layer (raw): $BRONZE_COUNT files"
        
        # Check Silver layer
        SILVER_COUNT=$(docker exec minio mc ls myminio/clinical-mlops/processed/ --recursive 2>/dev/null | wc -l || echo "0")
        echo "    Silver layer (processed): $SILVER_COUNT files"
        
        # Check Features
        FEATURES_COUNT=$(docker exec minio mc ls myminio/clinical-mlops/features/ --recursive 2>/dev/null | wc -l || echo "0")
        echo "    Feature store: $FEATURES_COUNT files"
        
        # Check Models
        MODELS_COUNT=$(docker exec minio mc ls myminio/clinical-mlops/models/ --recursive 2>/dev/null | wc -l || echo "0")
        echo "    Model registry: $MODELS_COUNT files"
        
        echo ""
        
        if [ "$BRONZE_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Data flowing into Bronze layer"
        else
            echo -e "    ${YELLOW}⚠${NC} No data in Bronze layer yet (wait 2-3 minutes)"
        fi
        
        if [ "$SILVER_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Data flowing into Silver layer"
        else
            echo -e "    ${YELLOW}⚠${NC} No data in Silver layer yet (wait 5-7 minutes)"
        fi
        
        if [ "$FEATURES_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Features generated"
        else
            echo -e "    ${YELLOW}⚠${NC} No features generated yet (wait 10+ minutes)"
        fi
        
        if [ "$MODELS_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Models registered"
        else
            echo -e "    ${YELLOW}⚠${NC} No models registered yet"
        fi
    else
        echo "  Data flow services not running - skipping data flow checks"
    fi
}

show_usage() {
    cat << EOF
${CYAN}Pipeline Health Check - Level Based${NC}

${GREEN}Usage:${NC}
  $0 [option]

${GREEN}Options:${NC}
  -l, --level <N>      Check health of specific level (0-$MAX_LEVEL)
  -f, --full           Check health of all levels (default)
  -d, --data-flow      Check data flow only
  -s, --status         Quick status check (services only)
  -h, --help           Show this help message

${GREEN}Examples:${NC}
  # Full health check (all levels + data flow)
  $0 --full
  
  # Check specific level
  $0 --level 0
  $0 --level 4
  
  # Check data flow only
  $0 --data-flow
  
  # Quick status check
  $0 --status

${GREEN}Levels:${NC}
  0: Infrastructure (minio, kafka, redis, postgres)
  1: Data Ingestion (kafka producers/consumers, data gateways)
  2: Data Processing (spark master/worker, streaming, batch)
  3: Feature Engineering (feature service)
  4: ML Pipeline (mlflow, training, model serving)
  5: Observability (airflow, prometheus, grafana, opensearch)

EOF
}

quick_status() {
    print_header "Quick Service Status"
    
    local total_running=0
    local total_services=0
    
    for level in $(seq 0 $MAX_LEVEL); do
        local services="${LEVEL_SERVICES[$level]}"
        local service_count=$(echo $services | wc -w)
        local running_count=0
        
        echo -e "${CYAN}Level $level: ${LEVEL_NAMES[$level]}${NC}"
        
        for service in $services; do
            ((total_services++))
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
                ((running_count++))
                ((total_running++))
            else
                echo -e "  ${RED}✗${NC} $service"
            fi
        done
        
        echo -e "  Status: $running_count/$service_count services running"
        echo ""
    done
    
    echo "═══════════════════════════════════════════════════════════"
    echo -e "Overall: $total_running/$total_services services running"
    echo "═══════════════════════════════════════════════════════════"
}

# --- Main Script ---

LEVEL_TO_CHECK=""
MODE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--level)
            LEVEL_TO_CHECK="$2"
            shift
            shift
            ;;
        -f|--full)
            MODE="full"
            shift
            ;;
        -d|--data-flow)
            MODE="data-flow"
            shift
            ;;
        -s|--status)
            MODE="status"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

case $MODE in
    status)
        quick_status
        exit 0
        ;;
    data-flow)
        print_header "Clinical MLOps - Data Flow Health Check"
        check_data_flow
        ;;
    full)
        print_header "Clinical MLOps - Full Pipeline Health Check"
        
        if [ -n "$LEVEL_TO_CHECK" ]; then
            # Check specific level
            if [ "$LEVEL_TO_CHECK" -lt 0 ] || [ "$LEVEL_TO_CHECK" -gt $MAX_LEVEL ]; then
                echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
                exit 1
            fi
            "check_level_$LEVEL_TO_CHECK"
        else
            # Check all levels
            for level in $(seq 0 $MAX_LEVEL); do
                "check_level_$level"
            done
            check_data_flow
        fi
        ;;
esac

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Health Check Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $CHECKS_PASSED"
echo -e "  ${RED}Failed:${NC}   $CHECKS_FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $CHECKS_WARNING"
echo ""

if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_WARNING -eq 0 ]; then
    echo -e "${GREEN}✓ Pipeline is perfectly healthy!${NC}"
    exit 0
elif [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${YELLOW}⚠ Pipeline is operational with some warnings${NC}"
    exit 0
else
    echo -e "${RED}✗ Pipeline has issues that need attention${NC}"
    echo ""
    echo "Common fixes:"
    echo "  • Start services: ./manage_pipeline.sh --start-level <N>"
    echo "  • Check status:   ./manage_pipeline.sh --status"
    echo "  • View logs:      ./manage_pipeline.sh --logs <N>"
    echo "  • Restart level:  ./manage_pipeline.sh --restart-level <N>"
    exit 1
fi