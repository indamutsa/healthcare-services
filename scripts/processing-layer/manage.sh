#!/bin/bash
#
# Data Processing Layer (Level 2) Management
# Orchestrates Spark master/worker and batch/streaming jobs
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script
DATA_PROCESSING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source data processing specific scripts
source "${DATA_PROCESSING_SCRIPT_DIR}/health-checks.sh"

# --- Data Processing Management Functions ---

# Start data processing services
start_data_processing() {
    local force_recreate=${1:-false}

    print_level_header 2 "Starting"

    # Check dependencies (Levels 0 and 1)
    for dependency in ${LEVEL_DEPENDENCIES[2]}; do
        case "$dependency" in
            0)
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
                ;;
            1)
                if ! check_level_running 1; then
                    echo -e "  ${YELLOW}⚠️  Dependency: Level 1 (Data Ingestion) not running${NC}"
                    echo -e "  ${CYAN}→ Auto-starting Level 1...${NC}"
                    echo ""
                    start_data_ingestion false
                    echo ""
                    echo -e "  ${GREEN}✓ Level 1 started${NC}"
                else
                    echo -e "  ${GREEN}✓ Dependency: Level 1 (Data Ingestion) running${NC}"
                fi
                ;;
        esac
    done
    echo ""

    local level2_running=false
    if check_level_running 2; then
        level2_running=true
    fi

    # Always show dependency services before managing Level 2
    if [ "$level2_running" = false ] || [ "$force_recreate" = true ]; then
        echo "Level 0 Services:"
        for service in ${LEVEL_SERVICES[0]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            else
                echo -e "  ${RED}✗${NC} $service"
            fi
        done

        echo ""
        echo "Level 1 Services:"
        for service in ${LEVEL_SERVICES[1]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            else
                echo -e "  ${RED}✗${NC} $service"
            fi
        done
        echo ""
    fi

    # Check if already running
    if [ "$level2_running" = true ] && [ "$force_recreate" != true ]; then
        log_info "Data Processing is already running"
        echo ""

        echo "Level 0 Services:"
        for service in ${LEVEL_SERVICES[0]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done

        echo ""
        echo "Level 1 Services:"
        for service in ${LEVEL_SERVICES[1]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done

        echo ""
        echo "Level 2 Services:"
        for service in ${LEVEL_SERVICES[2]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done
        return 0
    fi

    # List services to start
    echo "  Services to start:"
    for service in ${LEVEL_SERVICES[2]}; do
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
    docker_compose_up 2 "$force_recreate"

    echo ""
    echo -e "  ${GREEN}✓ Level 2 started${NC}"
    echo ""
    echo "Next Steps:"
    echo "  • View status:    ./pipeline-manager.sh --level 2 -s"
    echo "  • Follow logs:    ./pipeline-manager.sh --level 2 -l"
    echo "  • Run health:     ./pipeline-manager.sh --level 2 -h"
}

# Stop data processing services (CASCADE STOP: Level 2 → 1 → 0)
stop_data_processing() {
    local remove_volumes=${1:-true}

    print_header "🔻 Cascade Stop: Level 2 → 1 → 0"

    echo -e "${YELLOW}This will stop levels: 2, 1, 0${NC}"
    echo ""

    print_level_header 2 "Stopping"

    if check_level_running 2; then
        echo "Services to stop:"
        for service in ${LEVEL_SERVICES[2]}; do
            if check_service_running "$service"; then
                echo -e "  • $service ${RED}[STOPPING]${NC}"
            else
                echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
            fi
        done
        echo ""

        log_info "Stopping data processing services..."
        docker_compose_down 2 "$remove_volumes"

        if [ "$remove_volumes" = true ]; then
            log_warning "Volumes removed - processed data may be deleted"
        fi

        echo ""
        log_success "Level 2 stopped"
    else
        log_warning "Level 2 is already stopped"
    fi

    echo ""
    stop_data_ingestion "$remove_volumes"

    echo ""
    log_success "Cascade stop complete (Levels 2 → 0 stopped)"
}

# Restart data processing services
restart_data_processing() {
    print_level_header 2 "Restarting"

    log_info "Restarting data processing..."
    stop_data_processing false
    sleep 5
    start_data_processing false

    log_success "Data Processing (Level 2) restarted successfully"
}

# Rebuild data processing services from scratch
rebuild_data_processing() {
    print_header "🔄 Rebuilding Data Processing (Level 2)"

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop data processing services (cascade)"
    echo "  2. Rebuild all images"
    echo "  3. Force recreate all containers"
    echo ""

    log_info "Step 1: Stopping services..."
    stop_data_processing false

    log_info "Step 2: Building images..."
    docker_compose_build 2

    log_info "Step 3: Starting with force recreate..."
    start_data_processing true

    log_success "Data Processing rebuild complete!"
}

# Show data processing status
show_data_processing_status() {
    print_level_header 2 "Status"

    local services="${LEVEL_SERVICES[2]}"
    local running_count
    running_count=$(count_running_services 2)
    local total_count
    total_count=$(count_total_services 2)

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

    if [ "$running_count" -eq "$total_count" ]; then
        echo -e "${GREEN}✓ Data Processing is fully operational${NC}"
    elif [ "$running_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Data Processing is partially running${NC}"
    else
        echo -e "${RED}✗ Data Processing is stopped${NC}"
    fi
}

# Show URLs for data processing services
show_data_processing_urls() {
    print_header "Data Processing Service URLs"

    echo "Access your data processing services:"
    echo ""

    if check_service_running "spark-master"; then
        echo -e "  ${GREEN}✓${NC} Spark Master UI:   http://localhost:8080"
        echo "    Submit jobs or monitor executors"
        echo ""
    fi

    if check_service_running "spark-worker"; then
        echo -e "  ${GREEN}✓${NC} Spark Worker UI:   http://localhost:8081"
        echo ""
    fi

    if check_service_running "spark-streaming"; then
        echo -e "  ${GREEN}✓${NC} Spark Streaming:  docker logs spark-streaming"
        echo ""
    fi

    if check_service_running "spark-batch"; then
        echo -e "  ${GREEN}✓${NC} Spark Batch Job:  docker logs spark-batch"
        echo ""
    fi

    echo -e "${CYAN}Tip:${NC} Use MinIO (http://localhost:9001) to inspect processed data outputs."
}

# --- Export Functions ---
export -f start_data_processing
export -f stop_data_processing
export -f restart_data_processing
export -f rebuild_data_processing
export -f show_data_processing_status
export -f show_data_processing_urls
