#!/bin/bash
#
# ML Pipeline Health Checks
# Validates MLflow tracking server, training prerequisites, and model serving API
#
# Note: Common utilities must be sourced before this script

ML_PIPELINE_CHECKS_PASSED=0
ML_PIPELINE_CHECKS_FAILED=0
ML_PIPELINE_CHECKS_WARNING=0

# Run a single ML pipeline check with optional warning severity
run_ml_pipeline_check() {
    local description=$1
    local command=$2
    local is_warning=${3:-false}

    echo -n "  Testing: $description ... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((ML_PIPELINE_CHECKS_PASSED++))
        return 0
    fi

    if [ "$is_warning" = true ]; then
        echo -e "${YELLOW}⚠ WARNING${NC}"
        ((ML_PIPELINE_CHECKS_WARNING++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((ML_PIPELINE_CHECKS_FAILED++))
    fi
    return 1
}

# Check MLflow tracking server availability
check_mlflow_server() {
    log_info "Checking MLflow tracking server..."
    echo ""

    run_ml_pipeline_check "mlflow-server container running" \
        "check_service_running mlflow-server"

    if check_service_running mlflow-server; then
        run_ml_pipeline_check "MLflow /health endpoint" \
            "docker exec mlflow-server python -c \"import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()\""

        run_ml_pipeline_check "MLflow experiments API reachable" \
            "docker exec mlflow-server python -c \"import urllib.request; urllib.request.urlopen('http://localhost:5000/api/2.0/mlflow/experiments/list').read()\""

        run_ml_pipeline_check "MLflow artifacts bucket present" \
            "docker exec minio mc ls myminio/mlflow-artifacts >/dev/null 2>&1" \
            true
    else
        log_warning "MLflow server not running - skipping downstream checks"
    fi

    echo ""
}

# Check model serving API health
check_model_serving() {
    log_info "Checking model serving API..."
    echo ""

    run_ml_pipeline_check "model-serving container running" \
        "check_service_running model-serving"

    if check_service_running model-serving; then
        run_ml_pipeline_check "Model serving /health endpoint" \
            "curl -sf http://localhost:8000/health"

        run_ml_pipeline_check "Model serving docs reachable" \
            "curl -sf http://localhost:8000/docs" \
            true
    else
        log_warning "Model serving container not running - API checks skipped"
    fi

    echo ""
}

# Validate prerequisites for running training jobs
check_training_prerequisites() {
    log_info "Checking training prerequisites..."
    echo ""

    run_ml_pipeline_check "Training entrypoint present" \
        "test -f ./applications/ml-training/train.py"

    run_ml_pipeline_check "Training configuration present" \
        "test -f ./applications/ml-training/configs/model_config.yaml" \
        true

    if check_service_running minio; then
        docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true
        run_ml_pipeline_check "Offline features available in MinIO" \
            "docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | head -1" \
            true
    else
        log_warning "MinIO not running - cannot verify offline features"
        ((ML_PIPELINE_CHECKS_WARNING++))
    fi

    if check_service_running redis; then
        run_ml_pipeline_check "Redis reachable for online features" \
            "docker exec redis redis-cli PING"
    else
        log_warning "Redis not running - online feature validation skipped"
        ((ML_PIPELINE_CHECKS_WARNING++))
    fi

    echo ""
}

# Run full ML pipeline health checks
run_ml_pipeline_health_checks() {
    print_header "ML Pipeline Health Checks"

    ML_PIPELINE_CHECKS_PASSED=0
    ML_PIPELINE_CHECKS_FAILED=0
    ML_PIPELINE_CHECKS_WARNING=0

    check_mlflow_server
    check_model_serving
    check_training_prerequisites

    print_header "Health Check Summary"

    echo -e "  ${GREEN}Passed:${NC}   $ML_PIPELINE_CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $ML_PIPELINE_CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $ML_PIPELINE_CHECKS_WARNING"
    echo ""

    if [ $ML_PIPELINE_CHECKS_FAILED -eq 0 ] && [ $ML_PIPELINE_CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ ML Pipeline is fully operational${NC}"
        return 0
    elif [ $ML_PIPELINE_CHECKS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ ML Pipeline operational with warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ ML Pipeline issues detected${NC}"
        return 1
    fi
}

# Quick status for visualization mode
quick_ml_pipeline_status() {
    log_info "Quick ML Pipeline Status"
    echo ""

    for service in ${LEVEL_SERVICES[4]}; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done

    echo ""
    local running
    running=$(count_running_services 4)
    local total
    total=$(count_total_services 4)
    echo "Status: $running/$total services running"
    echo ""
}

# Highlight ML pipeline outputs for visualization mode
inspect_ml_pipeline_outputs() {
    log_info "Inspecting ML pipeline outputs..."
    echo ""

    if check_service_running mlflow-server; then
        local experiment_count=0
        local registered_models=0

        experiment_count=$(docker exec mlflow-server curl -s http://localhost:5000/api/2.0/mlflow/experiments/list 2>/dev/null | \
            python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('experiments', [])))" 2>/dev/null || echo "0")
        registered_models=$(docker exec mlflow-server curl -s http://localhost:5000/api/2.0/mlflow/registered-models/list 2>/dev/null | \
            python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('registered_models', [])))" 2>/dev/null || echo "0")

        echo "  MLflow Experiments:      ${experiment_count}"
        echo "  Registered Models:       ${registered_models}"
    else
        log_warning "MLflow server not running - metrics unavailable"
    fi

    if check_service_running minio; then
        docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true
        local artifact_files
        artifact_files=$(docker exec minio mc ls myminio/mlflow-artifacts --recursive 2>/dev/null | wc -l || echo "0")
        echo "  Artifact Objects (MinIO): ${artifact_files}"
    fi

    echo ""
    echo -e "${CYAN}Tip:${NC} Run ./pipeline-manager.sh --level 4 --run-training to trigger a new training job."
}

# Export public functions
export -f run_ml_pipeline_health_checks
export -f quick_ml_pipeline_status
export -f inspect_ml_pipeline_outputs
