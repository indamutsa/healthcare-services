#!/bin/bash
#
# Observability/Monitoring (Level 6) Management Script for Clinical MLOps Platform
# Handles Prometheus, Grafana, OpenSearch, Data Prepper, and Filebeat services
#
# Note: Common utilities must be sourced before this script

set -e

# Level 6 Services
OBSERVABILITY_SERVICES=(
    "prometheus"
    "grafana" 
    "opensearch"
    "opensearch-dashboards"
    "data-prepper"
    "filebeat"
    "monitoring-service"
)

# Start Observability Services
start_observability() {
    local rebuild="$1"

    print_level_header 6 "Starting"

    # Ensure Level 0 dependencies are running (infrastructure)
    log_info "Checking dependencies..."
    if ! check_level_running 0; then
        echo -e "  ${YELLOW}⚠️  Dependency: Level 0 (Infrastructure) not running${NC}"
        echo -e "  ${CYAN}→ Auto-starting Level 0...${NC}"
        echo ""
        start_infrastructure false
    fi

    # List services to start
    echo "  Services to start:"
    for service in "${OBSERVABILITY_SERVICES[@]}"; do
        if check_service_running "$service"; then
            if [ "$rebuild" = true ]; then
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
    log_info "Starting observability services..."
    
    if [ "$rebuild" = true ]; then
        docker compose --profile observability up -d --force-recreate
    else
        docker compose --profile observability up -d
    fi

    # Wait for services to be ready
    log_info "Waiting for observability services to be ready..."
    sleep 10

    # Verify services are running
    local all_running=true
    for service in "${OBSERVABILITY_SERVICES[@]}"; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service is running"
        else
            echo -e "  ${RED}✗${NC} $service failed to start"
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        log_success "Observability services started successfully"
    else
        log_warning "Some observability services may not be fully operational"
    fi

    echo ""
    echo -e "${CYAN}Observability URLs:${NC}"
    echo -e "  • Prometheus:     http://localhost:9090"
    echo -e "  • Grafana:        http://localhost:3000"
    echo -e "  • OpenSearch:     http://localhost:9200"
    echo -e "  • OpenSearch Dashboards: http://localhost:5601"
    echo ""
}

# Stop Observability Services
stop_observability() {
    local remove_containers="$1"
    local remove_volumes="$2"

    print_level_header 6 "Stopping"

    # List services to stop
    echo "  Services to stop:"
    for service in "${OBSERVABILITY_SERVICES[@]}"; do
        if check_service_running "$service"; then
            echo -e "    • $service ${YELLOW}[STOPPING]${NC}"
        else
            echo -e "    • $service ${GRAY}[NOT RUNNING]${NC}"
        fi
    done

    echo ""

    # Stop services
    log_info "Stopping observability services..."
    
    if [ "$remove_containers" = true ]; then
        if [ "$remove_volumes" = true ]; then
            docker compose --profile observability down --volumes
        else
            docker compose --profile observability down
        fi
    else
        docker compose --profile observability stop
    fi

    log_success "Observability services stopped successfully"
}

# Rebuild Observability Services
rebuild_observability() {
    print_level_header 6 "Rebuilding"

    log_info "Rebuilding observability services..."
    
    # Stop and remove containers
    docker compose --profile observability down --volumes
    
    # Rebuild and start
    docker compose --profile observability up -d --build

    # Wait for services to be ready
    log_info "Waiting for observability services to be ready..."
    sleep 15

    # Verify services are running
    local all_running=true
    for service in "${OBSERVABILITY_SERVICES[@]}"; do
        if check_service_running "$service"; then
            echo -e "  ${GREEN}✓${NC} $service is running"
        else
            echo -e "  ${RED}✗${NC} $service failed to start"
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        log_success "Observability services rebuilt and started successfully"
    else
        log_warning "Some observability services may not be fully operational"
    fi
}