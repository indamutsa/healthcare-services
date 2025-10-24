#!/bin/bash
#
# Feature Engineering Layer (Level 3) Management
# Orchestrates: Feature Engineering Service
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script
FEATURE_ENGINEERING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source feature engineering specific scripts
source "${FEATURE_ENGINEERING_SCRIPT_DIR}/health-checks.sh"

# --- Feature Engineering Management Functions ---

# Start feature engineering services
start_feature_engineering() {
    local force_recreate=${1:-false}

    print_level_header 3 "Starting"

    # Check dependencies (Levels 0, 1, 2)
    for dependency in ${LEVEL_DEPENDENCIES[3]}; do
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
            2)
                if ! check_level_running 2; then
                    echo -e "  ${YELLOW}⚠️  Dependency: Level 2 (Data Processing) not running${NC}"
                    echo -e "  ${CYAN}→ Auto-starting Level 2...${NC}"
                    echo ""
                    start_data_processing false
                    echo ""
                    echo -e "  ${GREEN}✓ Level 2 started${NC}"
                else
                    echo -e "  ${GREEN}✓ Dependency: Level 2 (Data Processing) running${NC}"
                fi
                ;;
        esac
    done
    echo ""

    local level3_running=false
    if check_level_running 3; then
        level3_running=true
    fi

    # Always display dependency services before managing Level 3
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

    echo "Level 2 Services:"
    for service in ${LEVEL_SERVICES[2]}; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done
    echo ""

    # If already running and not forcing recreate, show Level 3 services and exit
    if [ "$level3_running" = true ] && [ "$force_recreate" != true ]; then
        log_info "Feature Engineering is already running"
        echo ""

        echo "Level 3 Services:"
        for service in ${LEVEL_SERVICES[3]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done
        return 0
    fi

    # List services to start
    echo "  Services to start:"
    for service in ${LEVEL_SERVICES[3]}; do
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
    docker_compose_up 3 "$force_recreate"

    echo ""
    echo -e "  ${GREEN}✓ Level 3 started${NC}"
    echo ""
    echo "Next Steps:"
    echo "  • View status:    ./pipeline-manager.sh --level 3 -s"
    echo "  • Follow logs:    ./pipeline-manager.sh --level 3 -l"
    echo "  • Run health:     ./pipeline-manager.sh --level 3 -h"
}

# Stop feature engineering services (CASCADE STOP: stops Level 3 → 2 → 1 → 0)
stop_feature_engineering() {
    local remove_volumes=${1:-true}

    print_header "🔻 Cascade Stop: Level 3 → 2 → 1 → 0"

    echo -e "${YELLOW}This will stop levels: 3, 2, 1, 0${NC}"
    echo ""

    print_level_header 3 "Stopping"

    if check_level_running 3; then
        echo "Services to stop:"
        for service in ${LEVEL_SERVICES[3]}; do
            if check_service_running "$service"; then
                echo -e "  • $service ${RED}[STOPPING]${NC}"
            else
                echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
            fi
        done
        echo ""

        log_info "Stopping feature engineering services..."
        docker_compose_down 3 "$remove_volumes"

        if [ "$remove_volumes" = true ]; then
            log_warning "Volumes removed - feature artifacts may be deleted"
        fi

        echo ""
        log_success "Level 3 stopped"
    else
        log_warning "Level 3 is already stopped"
    fi

    echo ""
    stop_data_processing "$remove_volumes"

    echo ""
    log_success "Cascade stop complete (Levels 3 → 0 stopped)"
}

# Restart feature engineering services
restart_feature_engineering() {
    print_level_header 3 "Restarting"

    log_info "Restarting feature engineering..."
    stop_feature_engineering false
    sleep 5
    start_feature_engineering false

    log_success "Feature Engineering (Level 3) restarted successfully"
}

# Rebuild feature engineering from scratch
rebuild_feature_engineering() {
    print_header "🔨 Rebuilding Feature Engineering (Level 3)"

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop feature engineering services (cascade)"
    echo "  2. Rebuild the feature engineering image"
    echo "  3. Force recreate the container"
    echo ""

    log_info "Step 1: Stopping services..."
    stop_feature_engineering false

    log_info "Step 2: Building images..."
    docker_compose_build 3

    log_info "Step 3: Starting with force recreate..."
    start_feature_engineering true

    log_success "Feature Engineering rebuild complete!"
}

# Show feature engineering status
show_feature_engineering_status() {
    print_level_header 3 "Status"

    local services="${LEVEL_SERVICES[3]}"
    local running_count
    running_count=$(count_running_services 3)
    local total_count
    total_count=$(count_total_services 3)

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
        echo -e "${GREEN}✓ Feature Engineering is fully operational${NC}"
    elif [ "$running_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Feature Engineering is partially running${NC}"
    else
        echo -e "${RED}✗ Feature Engineering is stopped${NC}"
    fi
}

# Show feature engineering service URLs
show_feature_engineering_urls() {
    print_header "Feature Engineering Service URLs"

    echo "Access your feature engineering services:"
    echo ""

    echo "  📊 Offline Store (MinIO): http://localhost:9001"
    echo "    Path: clinical-mlops/features/offline/"
    echo ""

    echo "  ⚡ Online Store (Redis): localhost:6379"
    echo "    Keys: patient:*:features"
    echo ""

    echo -e "${CYAN}Tip:${NC} Use ./scripts/feature-engineering/compare_stores.sh to inspect feature stores."
}

# --- Export Functions ---
export -f start_feature_engineering
export -f stop_feature_engineering
export -f restart_feature_engineering
export -f rebuild_feature_engineering
export -f show_feature_engineering_status
export -f show_feature_engineering_urls
