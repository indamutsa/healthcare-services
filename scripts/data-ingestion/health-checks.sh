#!/bin/bash
#
# Data Ingestion Health Checks
# Validates all data ingestion services

# Track check results
DATA_INGESTION_CHECKS_PASSED=0
DATA_INGESTION_CHECKS_FAILED=0
DATA_INGESTION_CHECKS_WARNING=0

# Run a health check (reuse from infrastructure)
run_data_ingestion_check() {
    local test_name=$1
    local command=$2
    local is_warning=${3:-false}

    echo -n "  Testing: $test_name ... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((DATA_INGESTION_CHECKS_PASSED++))
        return 0
    else
        if [ "$is_warning" = true ]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((DATA_INGESTION_CHECKS_WARNING++))
            return 1
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((DATA_INGESTION_CHECKS_FAILED++))
            return 1
        fi
    fi
}

# Check Kafka Producer
check_kafka_producer() {
    log_info "Checking Kafka Producer..."
    echo ""

    run_data_ingestion_check "Kafka producer running" \
        "check_service_running kafka-producer"

    if check_service_running kafka-producer; then
        run_data_ingestion_check "Kafka producer logs accessible" \
            "docker logs kafka-producer 2>&1 | grep -q 'Started'" \
            true
    fi

    echo ""
}

# Check Kafka Consumer
check_kafka_consumer() {
    log_info "Checking Kafka Consumer..."
    echo ""

    run_data_ingestion_check "Kafka consumer running" \
        "check_service_running kafka-consumer"

    if check_service_running kafka-consumer; then
        run_data_ingestion_check "Kafka consumer connected" \
            "docker logs kafka-consumer 2>&1 | grep -q 'Subscribed'" \
            true
    fi

    echo ""
}

# Check Clinical Gateway
check_clinical_gateway() {
    log_info "Checking Clinical Data Gateway..."
    echo ""

    if check_service_running clinical-data-gateway; then
        run_data_ingestion_check "Clinical gateway running" \
            "check_service_running clinical-data-gateway"

        run_data_ingestion_check "Clinical gateway health endpoint" \
            "curl -sf http://localhost:8082/actuator/health" \
            true
    else
        echo -e "  ${YELLOW}⚠${NC} Clinical gateway not running (optional)"
    fi

    echo ""
}

# Check Clinical MQ
check_clinical_mq() {
    log_info "Checking Clinical MQ..."
    echo ""

    if check_service_running clinical-mq; then
        run_data_ingestion_check "Clinical MQ running" \
            "check_service_running clinical-mq"

        run_data_ingestion_check "Clinical MQ queue manager" \
            "docker exec clinical-mq dspmq 2>&1 | grep -q 'Running'" \
            true
    else
        echo -e "  ${YELLOW}⚠${NC} Clinical MQ not running (optional)"
    fi

    echo ""
}

# Comprehensive data ingestion health check
run_data_ingestion_health_checks() {
    print_header "Data Ingestion Health Checks"

    # Reset counters
    DATA_INGESTION_CHECKS_PASSED=0
    DATA_INGESTION_CHECKS_FAILED=0
    DATA_INGESTION_CHECKS_WARNING=0

    # Run checks
    check_kafka_producer
    check_kafka_consumer
    check_clinical_gateway
    check_clinical_mq

    # Show summary
    print_header "Health Check Summary"

    echo -e "  ${GREEN}Passed:${NC}   $DATA_INGESTION_CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $DATA_INGESTION_CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $DATA_INGESTION_CHECKS_WARNING"
    echo ""

    # Determine overall status
    if [ $DATA_INGESTION_CHECKS_FAILED -eq 0 ] && [ $DATA_INGESTION_CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ Data Ingestion is perfectly healthy!${NC}"
        return 0
    elif [ $DATA_INGESTION_CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Data Ingestion is operational with some warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Data Ingestion has issues that need attention${NC}"
        return 1
    fi
}

# Export functions
export -f run_data_ingestion_health_checks
export -f run_data_ingestion_check
export -f check_kafka_producer
export -f check_kafka_consumer
export -f check_clinical_gateway
export -f check_clinical_mq
