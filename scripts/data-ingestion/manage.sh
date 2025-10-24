#!/bin/bash
#
# Data Ingestion Layer (Level 1) Management
# Orchestrates: Kafka Producer/Consumer, Clinical MQ, Data Gateways
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script
DATA_INGESTION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source data-ingestion-specific scripts
source "${DATA_INGESTION_SCRIPT_DIR}/kafka-setup.sh"
source "${DATA_INGESTION_SCRIPT_DIR}/validators.sh"
source "${DATA_INGESTION_SCRIPT_DIR}/health-checks.sh"

# --- Data Ingestion Management Functions ---

# Start data ingestion services
start_data_ingestion() {
    local force_recreate=${1:-false}

    print_level_header 1 "Starting"

    # Check dependencies (Level 0)
    if ! check_level_running 0; then
        echo -e "  ${YELLOW}⚠️  Dependency: Level 0 (Infrastructure) not running${NC}"
        echo -e "  ${CYAN}→ Auto-starting Level 0...${NC}"
        echo ""
        start_infrastructure false
        echo ""
        echo -e "  ${GREEN}✓ Level 0 started${NC}"
    else
        echo -e "  ${GREEN}✓ Dependency: Level 0 (Infrastructure) running${NC}"
    fi
    echo ""

    # Check if already running
    if check_level_running 1 && [ "$force_recreate" != true ]; then
        log_info "Data Ingestion is already running"
        echo ""

        # Show Level 0 services
        echo "Level 0 Services:"
        for service in ${LEVEL_SERVICES[0]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done

        echo ""

        # Show Level 1 services
        echo "Level 1 Services:"
        for service in ${LEVEL_SERVICES[1]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done
        return 0
    fi

    # List services to start
    echo "  Services to start:"
    for service in ${LEVEL_SERVICES[1]}; do
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

    # Start services using docker compose
    docker_compose_up 1 "$force_recreate"

    echo ""
    echo -e "  ${GREEN}✓ Level 1 started${NC}"
    echo ""
    echo "Next Steps:"
    echo "  • View status:    ./manage_pipeline.sh --status"
    echo "  • Follow logs:    ./manage_pipeline.sh --logs <level>"
    echo "  • Check services: docker ps"
}

# Stop data ingestion services (CASCADE STOP: stops Level 1 → 0)
stop_data_ingestion() {
    local remove_volumes=${1:-true}

    print_header "🔻 Cascade Stop: Level 1 → 0"

    echo -e "${YELLOW}This will stop levels: 1, 0${NC}"
    echo ""

    # Stop Level 1 first
    print_level_header 1 "Stopping"

    if check_level_running 1; then
        # List services to stop
        echo "Services to stop:"
        for service in ${LEVEL_SERVICES[1]}; do
            if check_service_running "$service"; then
                echo -e "  • $service ${RED}[STOPPING]${NC}"
            else
                echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
            fi
        done
        echo ""

        # Stop services
        log_info "Stopping data ingestion services..."
        docker_compose_down 1 "$remove_volumes"

        if [ "$remove_volumes" = true ]; then
            log_warning "Volumes removed - ingested data has been deleted"
        fi

        echo ""
        log_success "Level 1 stopped"
    else
        log_warning "Level 1 is already stopped"
    fi

    # Then cascade to Level 0
    echo ""
    stop_infrastructure "$remove_volumes"

    echo ""
    log_success "Cascade stop complete (Levels 1 → 0 stopped)"
}

# Restart data ingestion services
restart_data_ingestion() {
    print_level_header 1 "Restarting"

    log_info "Restarting data ingestion..."
    stop_data_ingestion false
    sleep 5
    start_data_ingestion false

    log_success "Data Ingestion (Level 1) restarted successfully"
}

# Rebuild data ingestion from scratch
rebuild_data_ingestion() {
    print_header "= Rebuilding Data Ingestion (Level 1)"

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop data ingestion services"
    echo "  2. Rebuild all images"
    echo "  3. Force recreate all containers"
    echo ""

    # Stop services
    log_info "Step 1: Stopping services..."
    stop_data_ingestion false

    # Build images
    log_info "Step 2: Building images..."
    docker_compose_build 1

    # Start with force recreate
    log_info "Step 3: Starting with force recreate..."
    start_data_ingestion true

    log_success "Data Ingestion rebuild complete!"
}

# Show data ingestion status
show_data_ingestion_status() {
    print_level_header 1 "Status"

    local services="${LEVEL_SERVICES[1]}"
    local running_count=$(count_running_services 1)
    local total_count=$(count_total_services 1)

    echo "Services:"
    for service in $services; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}${NC} $service"
        else
            echo -e "  ${RED}${NC} $service"
        fi
    done

    echo ""
    echo "Status: $running_count/$total_count services running"

    if [ "$running_count" -eq "$total_count" ]; then
        echo -e "${GREEN} Data Ingestion is fully operational${NC}"
    elif [ "$running_count" -gt 0 ]; then
        echo -e "${YELLOW}� Data Ingestion is partially running${NC}"
    else
        echo -e "${RED} Data Ingestion is stopped${NC}"
    fi
}

# Show data ingestion service URLs
show_data_ingestion_urls() {
    print_header "Data Ingestion Service URLs"

    echo "Access your data ingestion services:"
    echo ""

    if check_service_running "clinical-data-gateway"; then
        echo -e "  ${GREEN}${NC} Clinical Data Gateway:  http://localhost:8082"
        echo "    POST /api/clinical/data"
        echo ""
    fi

    if check_service_running "lab-results-processor"; then
        echo -e "  ${GREEN}${NC} Lab Results Processor:  http://localhost:8083"
        echo "    Health: /actuator/health"
        echo ""
    fi

    if check_service_running "clinical-mq"; then
        echo -e "  ${GREEN}${NC} IBM MQ Console:         https://localhost:9443"
        echo "    Username: admin"
        echo "    Password: (check MQ_ADMIN_PASSWORD)"
        echo ""
    fi

    echo -e "${CYAN}Tip:${NC} Use Kafka UI (http://localhost:8090) to monitor message flow"
}

# Show data statistics
show_data_ingestion_stats() {
    print_header "Data Ingestion Statistics"

    if ! check_service_running "minio"; then
        log_warning "MinIO not running - cannot check data statistics"
        return
    fi

    # Configure MinIO alias
    docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true

    echo "Bronze Layer (Raw Data):"
    local bronze_count=$(docker exec minio mc ls myminio/clinical-mlops/raw/ --recursive 2>/dev/null | wc -l || echo "0")
    echo "  Files: $bronze_count"
    echo ""

    if check_service_running "kafka"; then
        echo "Kafka Topics:"
        docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | while read topic; do
            local count=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
                --broker-list localhost:9092 \
                --topic "$topic" \
                --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum}' || echo "0")
            echo "  • $topic: $count messages"
        done
    fi
}

# --- Export Functions ---
export -f start_data_ingestion
export -f stop_data_ingestion
export -f restart_data_ingestion
export -f rebuild_data_ingestion
export -f show_data_ingestion_status
export -f show_data_ingestion_urls
export -f show_data_ingestion_stats
