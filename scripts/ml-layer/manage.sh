#!/bin/bash
#
# ML Pipeline Layer (Level 4) Management
# Orchestrates: MLflow Tracking Server, Model Serving API, and training jobs
#
# Note: Common utilities must be sourced before this script

ML_LAYER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source ML layer health checks
source "${ML_LAYER_SCRIPT_DIR}/health-checks.sh"

# Map dependency levels to their respective auto-start handlers
declare -A LEVEL_START_HANDLERS=(
    [0]="start_infrastructure"
    [1]="start_data_ingestion"
    [2]="start_data_processing"
    [3]="start_feature_engineering"
)

# Ensure Levels 0-3 are running before activating Level 4
ensure_ml_pipeline_dependencies() {
    local dependency

    for dependency in ${LEVEL_DEPENDENCIES[4]}; do
        local handler="${LEVEL_START_HANDLERS[$dependency]}"
        local name="${LEVEL_NAMES[$dependency]}"

        if [ -z "$handler" ]; then
            echo -e "  ${YELLOW}⚠️  No auto-start handler defined for Level $dependency (${name})${NC}"
            continue
        fi

        if ! check_level_running "$dependency"; then
            echo -e "  ${YELLOW}⚠️  Dependency: Level $dependency (${name}) not running${NC}"
            echo -e "  ${CYAN}→ Auto-starting Level $dependency...${NC}"
            echo ""
            "$handler" false
            echo ""
        else
            echo -e "  ${GREEN}✓ Dependency: Level $dependency (${name}) running${NC}"
        fi
    done
}

# --- ML Pipeline Management Functions ---

start_ml_pipeline() {
    local force_recreate=${1:-false}

    print_level_header 4 "Starting"

    # Ensure dependencies (Levels 0-3) are running
    ensure_ml_pipeline_dependencies
    echo ""

    local level_running=false
    if check_level_running 4; then
        level_running=true
    fi

    if [ "$level_running" = true ] && [ "$force_recreate" != true ]; then
        log_info "ML Pipeline services already running"
        echo ""

        echo "Level 4 Services:"
        for service in ${LEVEL_SERVICES[4]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done
        echo ""
        echo "Trigger training anytime using: ./pipeline-manager.sh --level 4 --run-training"
        return 0
    fi

    echo "  Services to start:"
    for service in ${LEVEL_SERVICES[4]}; do
        if check_service_running "$service"; then
            if [ "$force_recreate" = true ]; then
                echo -e "    • $service ${YELLOW}[RESTARTING]${NC}"
            else
                echo -e "    • $service ${GREEN}[ALREADY RUNNING]${NC}"
            fi
        else
            echo -e "    • $service ${BLUE}[STARTING]${NC}"
        fi
    done
    echo ""

    docker_compose_up 4 "$force_recreate"

    # Wait for critical services
    wait_for_service mlflow-server 90 || true
    wait_for_service model-serving 90 || true

    local mlflow_url="http://localhost:${MLFLOW_TRACKING_PORT}"

    echo ""
    echo -e "  ${GREEN}✓ Level 4 started${NC}"
    echo ""
    echo "Next Steps:"
    echo "  • MLflow UI:     ${mlflow_url}"
    echo "  • Model API:     http://localhost:8000"
    echo "  • Run training:  ./pipeline-manager.sh --level 4 --run-training"
}

stop_ml_pipeline() {
    local remove_volumes=${1:-true}

    print_header "🔻 Cascade Stop: Level 4 → 3 → 2 → 1 → 0"
    print_level_header 4 "Stopping"

    if check_level_running 4; then
        echo "Services to stop:"
        for service in ${LEVEL_SERVICES[4]}; do
            if check_service_running "$service"; then
                echo -e "  • $service ${RED}[STOPPING]${NC}"
            else
                echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
            fi
        done
        echo ""

        log_info "Stopping ML pipeline services..."
        docker_compose_down 4 "$remove_volumes"

        if [ "$remove_volumes" = true ]; then
            log_warning "Volumes removed - ML artifacts may be deleted"
        fi

        log_success "Level 4 stopped"
    else
        log_warning "Level 4 already stopped"
    fi

    echo ""
    stop_feature_engineering "$remove_volumes"

    echo ""
    log_success "Cascade stop complete (Levels 4 → 0 stopped)"
}

rebuild_ml_pipeline() {
    print_header "🔨 Rebuilding ML Pipeline (Level 4)"

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop ML pipeline services (cascade)"
    echo "  2. Rebuild MLflow and model-serving images"
    echo "  3. Force recreate containers"
    echo ""

    log_info "Step 1: Stopping services..."
    stop_ml_pipeline false

    log_info "Step 2: Building images..."
    docker_compose_build 4

    log_info "Step 3: Starting with force recreate..."
    start_ml_pipeline true

    log_success "ML Pipeline rebuild complete!"
}

show_ml_pipeline_status() {
    print_level_header 4 "Status"

    local services="${LEVEL_SERVICES[4]}"
    local running_count
    running_count=$(count_running_services 4)
    local total_count
    total_count=$(count_total_services 4)

    echo "Services:"
    for service in $services; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done

    echo ""
    echo "Status: $running_count/$total_count services running"

    if [ "$running_count" -eq "$total_count" ] && [ "$total_count" -gt 0 ]; then
        echo -e "${GREEN}✓ ML Pipeline is fully operational${NC}"
    elif [ "$running_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ ML Pipeline is partially running${NC}"
    else
        echo -e "${RED}✗ ML Pipeline is stopped${NC}"
    fi

    echo ""
    if docker ps -a --format '{{.Names}} {{.Status}}' | grep -q "^ml-training "; then
        local training_status
        training_status=$(docker ps -a --format '{{.Names}} {{.Status}}' | awk '/^ml-training /{print substr($0, index($0,$2))}')
        echo "Training container status: $training_status"
    else
        echo "Training container: not yet executed"
    fi
}

show_ml_pipeline_urls() {
    print_header "ML Pipeline Service URLs"

    local mlflow_url="http://localhost:${MLFLOW_TRACKING_PORT}"

    if check_service_running mlflow-server; then
        echo -e "  ${GREEN}✓${NC} MLflow Tracking UI: ${mlflow_url}"
    else
        echo -e "  ${RED}✗${NC} MLflow Tracking UI: ${mlflow_url}"
    fi

    if check_service_running model-serving; then
        echo -e "  ${GREEN}✓${NC} Model Serving API:  http://localhost:8000"
        echo "    Swagger docs:           http://localhost:8000/docs"
    else
        echo -e "  ${RED}✗${NC} Model Serving API:  http://localhost:8000"
    fi

    echo ""
    echo -e "${CYAN}Tip:${NC} Run training with: ./pipeline-manager.sh --level 4 --run-training"
}

# Run ML training job on demand
run_ml_training_job() {
    print_header "🎯 Running ML Training Pipeline"

    if ! check_level_running 4; then
        log_warning "Level 4 services are not running - auto-starting prerequisites"
        start_ml_pipeline false
    fi

    if ! check_service_running mlflow-server; then
        log_error "MLflow server must be running before training"
        exit 1
    fi

    echo ""
    log_info "Launching training container..."
    docker compose --profile ml-pipeline run --rm ml-training python train.py
    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "Training completed successfully"
        echo "View results: http://localhost:${MLFLOW_TRACKING_PORT}"
    else
        log_error "Training failed - check docker compose logs ml-training"
        exit $exit_code
    fi
}

# Export functions
export -f start_ml_pipeline
export -f stop_ml_pipeline
export -f rebuild_ml_pipeline
export -f show_ml_pipeline_status
export -f show_ml_pipeline_urls
export -f run_ml_training_job
