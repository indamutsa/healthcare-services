#!/bin/bash
#
# Data Processing Health Checks
# Validates Spark services powering Level 2

# Track check results
DATA_PROCESSING_CHECKS_PASSED=0
DATA_PROCESSING_CHECKS_FAILED=0
DATA_PROCESSING_CHECKS_WARNING=0

# Run a data processing health check
run_data_processing_check() {
    local test_name=$1
    local command=$2
    local is_warning=${3:-false}

    echo -n "  Testing: $test_name ... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((DATA_PROCESSING_CHECKS_PASSED++))
        return 0
    else
        if [ "$is_warning" = true ]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((DATA_PROCESSING_CHECKS_WARNING++))
            return 1
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((DATA_PROCESSING_CHECKS_FAILED++))
            return 1
        fi
    fi
}

# Check Spark Master health
check_spark_master() {
    log_info "Checking Spark Master..."
    echo ""

    run_data_processing_check "Spark master container running" \
        "check_service_running spark-master" || true

    if check_service_running spark-master; then
        run_data_processing_check "Spark master UI reachable (http://localhost:8080)" \
            "curl -sf http://localhost:8080" \
            true || true
    fi

    echo ""
}

# Check Spark Worker health
check_spark_worker() {
    log_info "Checking Spark Worker..."
    echo ""

    run_data_processing_check "Spark worker container running" \
        "check_service_running spark-worker" || true

    if check_service_running spark-worker; then
        run_data_processing_check "Spark worker UI reachable (http://localhost:8081)" \
            "curl -sf http://localhost:8081" \
            true || true
    fi

    echo ""
}

# Check Spark Streaming job
check_spark_streaming() {
    log_info "Checking Spark Streaming..."
    echo ""

    if check_service_running spark-streaming; then
        run_data_processing_check "Spark streaming container running" \
            "check_service_running spark-streaming" || true

        run_data_processing_check "Spark streaming processing logs available" \
            "docker logs spark-streaming 2>&1 | grep -q 'Streaming job started'" \
            true || true
    else
        echo -e "  ${YELLOW}⚠${NC} Spark streaming job not running (optional)"
    fi

    echo ""
}

# Check Spark Batch job
check_spark_batch() {
    log_info "Checking Spark Batch..."
    echo ""

    if check_service_running spark-batch; then
        run_data_processing_check "Spark batch container running" \
            "check_service_running spark-batch" || true

        run_data_processing_check "Spark batch completed recent run" \
            "docker logs spark-batch 2>&1 | grep -q 'Batch job completed'" \
            true || true
    else
        echo -e "  ${YELLOW}⚠${NC} Spark batch job not running (on-demand)"
    fi

    echo ""
}

# Run all data processing health checks
run_data_processing_health_checks() {
    print_header "Data Processing Health Checks"

    DATA_PROCESSING_CHECKS_PASSED=0
    DATA_PROCESSING_CHECKS_FAILED=0
    DATA_PROCESSING_CHECKS_WARNING=0

    check_spark_master
    check_spark_worker
    check_spark_streaming
    check_spark_batch

    print_header "Health Check Summary"

    echo -e "  ${GREEN}Passed:${NC}   $DATA_PROCESSING_CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $DATA_PROCESSING_CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $DATA_PROCESSING_CHECKS_WARNING"
    echo ""

    if [ $DATA_PROCESSING_CHECKS_FAILED -eq 0 ] && [ $DATA_PROCESSING_CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ Data Processing is perfectly healthy!${NC}"
        return 0
    elif [ $DATA_PROCESSING_CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Data Processing is operational with some warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Data Processing has issues that need attention${NC}"
        return 1
    fi
}

# Quick status view for visualization
quick_data_processing_status() {
    log_info "Quick Data Processing Status"
    echo ""

    local services="${LEVEL_SERVICES[2]}"

    for service in $services; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done

    echo ""

    local running=$(count_running_services 2)
    local total=$(count_total_services 2)
    echo "Status: $running/$total services running"
}

# Summarize Spark outputs stored in MinIO
inspect_spark_outputs() {
    log_info "Inspecting Spark outputs..."
    echo ""

    if ! check_service_running "minio"; then
        log_warning "MinIO is not running - cannot inspect processed data"
        return
    fi

    docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true

    local silver_count
    silver_count=$(docker exec minio mc ls myminio/clinical-mlops/processed/ --recursive 2>/dev/null | wc -l || echo "0")
    echo "  Processed (silver) artifacts: $silver_count files"

    local gold_count
    gold_count=$(docker exec minio mc ls myminio/clinical-mlops/enriched/ --recursive 2>/dev/null | wc -l || echo "0")
    echo "  Enriched (gold) artifacts:   $gold_count files"

    echo ""
    echo -e "${CYAN}Tip:${NC} Use 'docker logs spark-streaming' to monitor live processing."
}

# Export functions
export -f run_data_processing_health_checks
export -f run_data_processing_check
export -f check_spark_master
export -f check_spark_worker
export -f check_spark_streaming
export -f check_spark_batch
export -f quick_data_processing_status
export -f inspect_spark_outputs
