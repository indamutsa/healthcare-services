#!/bin/bash
#
# Infrastructure Layer (Level 0) Management
# Orchestrates: MinIO, PostgreSQL, Redis, Kafka, Zookeeper
#
# Note: Common utilities (config.sh, utils.sh, validation.sh) must be sourced before this script

# Get the directory of this script
INFRA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source infrastructure-specific scripts
source "${INFRA_SCRIPT_DIR}/init-minio.sh"
source "${INFRA_SCRIPT_DIR}/init-postgres.sh"
source "${INFRA_SCRIPT_DIR}/init-kafka.sh"
source "${INFRA_SCRIPT_DIR}/health-checks.sh"

# --- Infrastructure Management Functions ---

# Start infrastructure services
start_infrastructure() {
    local force_recreate=${1:-false}

    print_level_header 0 "Starting"

    # Check if already running
    if check_level_running 0 && [ "$force_recreate" != true ]; then
        log_info "Infrastructure is already running"
        echo ""
        echo "Services:"
        for service in ${LEVEL_SERVICES[0]}; do
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
            fi
        done
        return 0
    fi

    # List services to start
    echo "  Services to start:"
    for service in ${LEVEL_SERVICES[0]}; do
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

    # Add minio-setup to the list
    echo -e "    • minio-setup ${BLUE}[STARTING]${NC}"
    echo ""

    # Start services using docker compose
    docker_compose_up 0 "$force_recreate"

    echo ""
    echo -e "  ${GREEN}✓ Level 0 started${NC}"
}

# Stop infrastructure services
stop_infrastructure() {
    local remove_volumes=${1:-true}  # Default to removing volumes
    local cascade=${2:-true}  # Parameter for consistency (not used at level 0)

    print_level_header 0 "Stopping"

    if ! check_level_running 0; then
        log_warning "Infrastructure is already stopped"
        return 0
    fi

    # List services to stop
    echo "Services to stop:"
    for service in ${LEVEL_SERVICES[0]}; do
        if check_service_running "$service"; then
            echo -e "  • $service ${RED}[STOPPING]${NC}"
        else
            echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
        fi
    done
    echo ""

    # Stop services
    log_info "Stopping infrastructure services..."
    docker_compose_down 0 "$remove_volumes"

    if [ "$remove_volumes" = true ]; then
        log_warning "Volumes removed - all data has been deleted"
    fi

    log_success "Infrastructure (Level 0) stopped successfully"
}

# Restart infrastructure services
restart_infrastructure() {
    print_level_header 0 "Restarting"
    
    log_info "Restarting infrastructure..."
    stop_infrastructure false
    sleep 5
    start_infrastructure false
    
    log_success "Infrastructure (Level 0) restarted successfully"
}

# Rebuild infrastructure from scratch
rebuild_infrastructure() {
    print_header "🔄 Rebuilding Infrastructure (Level 0)"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop all infrastructure services"
    echo "  2. Rebuild all images"
    echo "  3. Force recreate all containers"
    echo ""
    
    # Stop services
    log_info "Step 1: Stopping services..."
    stop_infrastructure false
    
    # Build images
    log_info "Step 2: Building images..."
    docker_compose_build 0
    
    # Start with force recreate
    log_info "Step 3: Starting with force recreate..."
    start_infrastructure true
    
    log_success "Infrastructure rebuild complete!"
}

# Show infrastructure status
show_infrastructure_status() {
    print_level_header 0 "Status"
    
    local services="${LEVEL_SERVICES[0]}"
    local running_count=$(count_running_services 0)
    local total_count=$(count_total_services 0)
    
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
        echo -e "${GREEN}✓ Infrastructure is fully operational${NC}"
    elif [ "$running_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Infrastructure is partially running${NC}"
    else
        echo -e "${RED}✗ Infrastructure is stopped${NC}"
    fi
}

# Show service URLs
show_service_urls() {
    print_header "Infrastructure Service URLs"

    echo "Access your infrastructure services:"
    echo ""

    if check_service_running "minio"; then
        echo -e "  ${GREEN}✓${NC} MinIO Console:      http://localhost:9001"
        echo "    Username: minioadmin"
        echo "    Password: minioadmin"
        echo ""
    fi

    if check_service_running "kafka-ui"; then
        echo -e "  ${GREEN}✓${NC} Kafka UI:           http://localhost:8090"
        echo ""
    fi

    if check_service_running "redis-insight"; then
        echo -e "  ${GREEN}✓${NC} Redis Insight:      http://localhost:5540"
        echo ""
    fi

    if check_service_running "postgres-mlflow"; then
        echo -e "  ${GREEN}✓${NC} PostgreSQL MLflow:  localhost:5432"
        echo "    Database: mlflow"
        echo "    Username: mlflow"
        echo "    Password: mlflow"
        echo ""
    fi

    if check_service_running "postgres-airflow"; then
        echo -e "  ${GREEN}✓${NC} PostgreSQL Airflow: localhost:5433"
        echo "    Database: airflow"
        echo "    Username: airflow"
        echo "    Password: airflow"
        echo ""
    fi

    echo -e "${CYAN}Tip:${NC} Use these URLs to access and monitor your infrastructure"
}

# --- Export Functions ---
export -f start_infrastructure
export -f stop_infrastructure
export -f restart_infrastructure
export -f rebuild_infrastructure
export -f show_infrastructure_status
export -f show_service_urls