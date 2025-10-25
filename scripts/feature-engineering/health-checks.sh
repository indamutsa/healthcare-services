#!/bin/bash
#
# Feature Engineering Health Checks
# Validates offline and online feature stores plus service availability

# Track check results
FEATURE_ENGINEERING_CHECKS_PASSED=0
FEATURE_ENGINEERING_CHECKS_FAILED=0
FEATURE_ENGINEERING_CHECKS_WARNING=0

# Run a feature engineering health check
run_feature_engineering_check() {
    local test_name=$1
    local command=$2
    local is_warning=${3:-false}

    echo -n "  Testing: $test_name ... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((FEATURE_ENGINEERING_CHECKS_PASSED++))
        return 0
    else
        if [ "$is_warning" = true ]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((FEATURE_ENGINEERING_CHECKS_WARNING++))
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((FEATURE_ENGINEERING_CHECKS_FAILED++))
        fi
        return 1
    fi
}

# Check feature engineering service and stores
check_feature_engineering_service() {
    log_info "Checking Feature Engineering Service..."
    echo ""

    run_feature_engineering_check "Feature engineering container running" \
        "check_service_running feature-engineering"

    if check_service_running feature-engineering; then
        run_feature_engineering_check "MinIO alias configured" \
            "docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1"

        run_feature_engineering_check "MinIO offline features present" \
            "docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | head -1" \
            true

        run_feature_engineering_check "Redis feature keys available" \
            "docker exec redis redis-cli --raw KEYS 'patient:*:features' | head -1" \
            true

        run_feature_engineering_check "Redis accessible for feature store" \
            "docker exec redis redis-cli ping"

        run_feature_engineering_check "MinIO accessible for feature storage" \
            "docker exec minio mc ls myminio/clinical-mlops/features/offline/ >/dev/null 2>&1"
    fi

    echo ""
}

# Run all feature engineering health checks
run_feature_engineering_health_checks() {
    print_header "Feature Engineering Health Checks"

    FEATURE_ENGINEERING_CHECKS_PASSED=0
    FEATURE_ENGINEERING_CHECKS_FAILED=0
    FEATURE_ENGINEERING_CHECKS_WARNING=0

    check_feature_engineering_service

    print_header "Health Check Summary"

    echo -e "  ${GREEN}Passed:${NC}   $FEATURE_ENGINEERING_CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $FEATURE_ENGINEERING_CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $FEATURE_ENGINEERING_CHECKS_WARNING"
    echo ""

    if [ $FEATURE_ENGINEERING_CHECKS_FAILED -eq 0 ] && [ $FEATURE_ENGINEERING_CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ Feature Engineering is fully operational${NC}"
        return 0
    elif [ $FEATURE_ENGINEERING_CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Feature Engineering is operational with some warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Feature Engineering has issues that need attention${NC}"
        return 1
    fi
}

# Quick status for visualization
quick_feature_engineering_status() {
    log_info "Quick Feature Engineering Status"
    echo ""

    for service in ${LEVEL_SERVICES[3]}; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done

    echo ""
    local running=$(count_running_services 3)
    local total=$(count_total_services 3)
    echo "Status: $running/$total services running"
    echo ""
}

# Inspect feature stores for visualize
inspect_feature_store_outputs() {
    log_info "Inspecting feature stores..."
    echo ""

    if check_service_running "minio"; then
        docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true
        local offline_count
        offline_count=$(docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | wc -l || echo "0")
        echo "  Offline features (MinIO): $offline_count files"
    else
        log_warning "MinIO not running - offline store unavailable"
    fi

    if check_service_running "redis"; then
        local online_keys
        online_keys=$(docker exec redis redis-cli --raw KEYS 'patient:*:features' 2>/dev/null | wc -l || echo "0")
        echo "  Online features (Redis):  $online_keys keys"
    else
        log_warning "Redis not running - online store unavailable"
    fi

    echo ""
    echo -e "${CYAN}Tip:${NC} Run ./scripts/feature-engineering/compare_stores.sh for detailed store comparison."
}

# Export functions
export -f run_feature_engineering_health_checks
export -f run_feature_engineering_check
export -f check_feature_engineering_service
export -f quick_feature_engineering_status
export -f inspect_feature_store_outputs
