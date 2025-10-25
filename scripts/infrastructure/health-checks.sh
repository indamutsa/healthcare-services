#!/bin/bash
#
# Infrastructure Health Checks
# Validates all infrastructure services and connectivity
#
# Note: Common utilities and init scripts must be sourced before this script

# Get the directory of this script
HEALTH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Track check results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# --- Health Check Functions ---

# Run a health check
run_check() {
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

# --- MinIO Health Checks ---

check_minio() {
    log_info "Checking MinIO..."
    echo ""
    
    run_check "MinIO server accessible" \
        "curl -sf ${MINIO_ENDPOINT}/minio/health/live" || true
    
    run_check "MinIO setup completed" \
        "docker logs minio-setup 2>&1 | grep -q 'Buckets successfully configured'" \
        true || true
    
    run_check "MinIO client configured" \
        "docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin" || true
    
    # Check buckets
    for bucket in $MINIO_BUCKETS; do
        run_check "Bucket '$bucket' exists" \
            "check_bucket_exists '$bucket'" || true
    done
    
    echo ""
}

# --- Kafka Health Checks ---

check_kafka() {
    log_info "Checking Kafka..."
    echo ""
    
    run_check "Zookeeper running" \
        "docker exec zookeeper /bin/sh -c 'echo srvr | nc localhost 2181' | grep -q Mode" || true
    
    run_check "Kafka broker accessible" \
        "docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092" || true
    
    run_check "Kafka UI accessible" \
        "curl -sf http://localhost:8090" \
        true || true
    
    # Check if topics exist (warning if not)
    run_check "Kafka topics exist" \
        "docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | head -1" \
        true || true
    
    echo ""
}

# --- PostgreSQL Health Checks ---

check_postgres() {
    log_info "Checking PostgreSQL..."
    echo ""
    
    run_check "PostgreSQL MLflow accessible" \
        "check_postgres_mlflow_ready" || true
    
    run_check "PostgreSQL Airflow accessible" \
        "check_postgres_airflow_ready" || true
    
    # Check database connectivity
    run_check "MLflow database exists" \
        "docker exec postgres-mlflow psql -U mlflow -lqt | cut -d \| -f 1 | grep -qw mlflow" || true
    
    run_check "Airflow database exists" \
        "docker exec postgres-airflow psql -U airflow -lqt | cut -d \| -f 1 | grep -qw airflow" || true
    
    echo ""
}

# --- Redis Health Checks ---

check_redis() {
    log_info "Checking Redis..."
    echo ""
    
    run_check "Redis server accessible" \
        "docker exec redis redis-cli ping" || true
    
    run_check "Redis can set/get keys" \
        "docker exec redis redis-cli set healthcheck 'ok' && docker exec redis redis-cli get healthcheck | grep -q 'ok'" || true
    
    run_check "Redis Insight accessible" \
        "curl -sf http://localhost:5540" \
        true || true
    
    # Clean up test key
    docker exec redis redis-cli del healthcheck > /dev/null 2>&1 || true
    
    echo ""
}

# --- Comprehensive Infrastructure Health Check ---

run_infrastructure_health_checks() {
    print_header "Infrastructure Health Checks"
    
    # Reset counters
    CHECKS_PASSED=0
    CHECKS_FAILED=0
    CHECKS_WARNING=0
    
    # Run checks for each service type
    check_minio
    check_kafka
    check_postgres
    check_redis
    
    # Show summary
    print_header "Health Check Summary"
    
    echo -e "  ${GREEN}Passed:${NC}   $CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $CHECKS_WARNING"
    echo ""
    
    # Determine overall status
    if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ Infrastructure is perfectly healthy!${NC}"
        return 0
    elif [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Infrastructure is operational with some warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Infrastructure has issues that need attention${NC}"
        echo ""
        echo "Suggestions:"
        echo "  • Check logs: docker compose logs <service>"
        echo "  • Restart services: ./scripts/infrastructure/manage.sh --restart"
        echo "  • Rebuild: ./scripts/infrastructure/manage.sh --rebuild"
        return 1
    fi
}

# Quick service status check
quick_infrastructure_status() {
    log_info "Quick Infrastructure Status"
    echo ""
    
    local services="${LEVEL_SERVICES[0]}"
    
    for service in $services; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done
    
    echo ""
    
    local running=$(count_running_services 0)
    local total=$(count_total_services 0)
    
    echo "Status: $running/$total services running"
    echo ""
}

# Check data accessibility
check_data_accessibility() {
    log_info "Checking data accessibility..."
    echo ""
    
    # Check MinIO data
    if check_service_running "minio"; then
        configure_minio_alias > /dev/null 2>&1
        
        for bucket in $MINIO_BUCKETS; do
            local count=$(docker exec minio mc ls "myminio/${bucket}/" --recursive 2>/dev/null | wc -l || echo "0")
            echo "  Bucket '$bucket': $count items"
        done
    else
        log_warning "MinIO not running, skipping data checks"
    fi
    
    echo ""
}

# Export functions
export -f run_infrastructure_health_checks
export -f quick_infrastructure_status
export -f check_data_accessibility
export -f run_check
export -f check_minio
export -f check_kafka
export -f check_postgres
export -f check_redis
