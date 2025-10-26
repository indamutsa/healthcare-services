#!/bin/bash
#
# Orchestration (Airflow) Management Script for Clinical MLOps Platform
# Handles Airflow webserver, scheduler, and worker services
#
# Note: Common utilities must be sourced before this script

set -e

# Level 5 Services
ORCHESTRATION_SERVICES=(
    "postgres-airflow"
    "airflow-init"
    "airflow-webserver"
    "airflow-scheduler"
)

# Start Orchestration Services
start_orchestration() {
    local rebuild="$1"

    print_level_header 5 "Starting"

    # Ensure Level 4 dependencies are running
    log_info "Checking dependencies..."
    if ! check_level_running 4; then
        echo -e "  ${YELLOW}⚠️  Dependency: Level 4 (ML Pipeline) not running${NC}"
        echo -e "  ${CYAN}→ Auto-starting Level 4...${NC}"
        echo ""
        start_ml_pipeline false
        echo ""
        echo -e "  ${GREEN}✓ Level 4 started${NC}"
    else
        echo -e "  ${GREEN}✓ Dependency: Level 4 (ML Pipeline) running${NC}"
    fi

    # Build Airflow image if needed
    if [ "$rebuild" = true ]; then
        log_info "Building Airflow image..."
        docker compose build airflow-webserver airflow-scheduler
    fi

    # Start orchestration services
    log_info "Starting orchestration services..."
    docker compose up -d "${ORCHESTRATION_SERVICES[@]}"

    # Wait for services to be ready
    log_info "Waiting for Airflow services to be ready..."
    sleep 30

    # Check Airflow health
    check_airflow_health

    log_success "Airflow orchestration layer started successfully"
    log_info "Airflow Webserver: http://localhost:8085"
    log_info "Default credentials: admin / admin"
}

# Stop Orchestration Services
stop_orchestration() {
    local remove_volumes="$1"
    local cascade="${2:-true}"

    print_header "🔻 Cascade Stop: Level 5 → 4 → 3 → 2 → 1 → 0"

    echo -e "${YELLOW}This will stop levels: 5, 4, 3, 2, 1, 0${NC}"
    echo ""

    print_level_header 5 "Stopping"

    if check_level_running 5; then
        echo "Services to stop:"
        for service in ${LEVEL_SERVICES[5]}; do
            if check_service_running "$service"; then
                echo -e "  • $service ${RED}[STOPPING]${NC}"
            else
                echo -e "  • $service ${YELLOW}[ALREADY STOPPED]${NC}"
            fi
        done
        echo ""

        log_info "Stopping orchestration services..."
        docker_compose_down 5 "$remove_volumes"

        if [ "$remove_volumes" = true ]; then
            log_warning "Airflow volumes and data have been removed"
        else
            log_success "Airflow services stopped (volumes preserved)"
        fi
    else
        log_warning "Level 5 is already stopped"
    fi

    # Then cascade to lower levels if requested
    if [ "$cascade" = true ]; then
        echo ""
        stop_ml_pipeline "$remove_volumes" "$cascade"
        echo ""
        log_success "Cascade stop complete (Levels 5 → 0 stopped)"
    else
        echo ""
        log_success "Level 5 stopped (no cascade)"
    fi
}

# Rebuild Orchestration Services
rebuild_orchestration() {
    print_header "🔄 Rebuilding Level 5 - Orchestration (Airflow)"

    stop_orchestration false
    start_orchestration true
}

# Check Airflow Health
check_airflow_health() {
    log_info "Checking Airflow services health..."

    local webserver_healthy=false
    local scheduler_healthy=false
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt $attempt/$max_attempts..."

        # Check webserver
        if curl -f http://localhost:8085/health >/dev/null 2>&1; then
            webserver_healthy=true
            log_success "Airflow webserver is healthy"
        else
            log_warning "Airflow webserver not ready yet..."
        fi

        # Check scheduler
        if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
            scheduler_healthy=true
            log_success "Airflow scheduler is healthy"
        else
            log_warning "Airflow scheduler not ready yet..."
        fi

        if [ "$webserver_healthy" = true ] && [ "$scheduler_healthy" = true ]; then
            return 0
        fi

        sleep 10
        ((attempt++))
    done

    log_error "Airflow health check failed after $max_attempts attempts"
    return 1
}

# Check MLflow dependency
check_mlflow_running() {
    # Check if MLflow container is running
    if docker compose ps mlflow-server --format "table {{.Status}}" | grep -q "Up"; then
        return 0
    else
        return 1
    fi
}

# Show Orchestration Status
show_orchestration_status() {
    print_header "📊 Orchestration (Airflow) Status"

    echo -e "${CYAN}Containers:${NC}"
    docker compose ps "${ORCHESTRATION_SERVICES[@]}" --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    echo -e "${CYAN}Service URLs:${NC}"
    echo "  • Airflow Webserver: http://localhost:8085"

    echo ""
    echo -e "${CYAN}Health Status:${NC}"
    if curl -f http://localhost:8085/health >/dev/null 2>&1; then
        echo "  • Webserver: ${GREEN}Healthy${NC}"
    else
        echo "  • Webserver: ${RED}Unhealthy${NC}"
    fi

    if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
        echo "  • Scheduler: ${GREEN}Healthy${NC}"
    else
        echo "  • Scheduler: ${RED}Unhealthy${NC}"
    fi
}

# Show Orchestration URLs
show_orchestration_urls() {
    print_header "🔗 Orchestration Service URLs"

    echo "  • Airflow Webserver: http://localhost:8085"
    echo "    - Default credentials: admin / admin"
    echo "    - DAGs: Clinical Data Pipeline, Model Monitoring, etc."
    echo ""
    echo "  • Useful endpoints:"
    echo "    - Health: http://localhost:8085/health"
    echo "    - API: http://localhost:8085/api/v1/"
}

# Run Orchestration Health Checks
run_orchestration_health_checks() {
    print_header "🏥 Orchestration Health Checks"

    local all_healthy=true

    echo -e "${CYAN}Checking Airflow Webserver...${NC}"
    if curl -f http://localhost:8085/health >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Webserver responding"
    else
        echo "  ${RED}✗${NC} Webserver not responding"
        all_healthy=false
    fi

    echo -e "${CYAN}Checking Airflow Scheduler...${NC}"
    if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Scheduler running"
    else
        echo "  ${RED}✗${NC} Scheduler not running"
        all_healthy=false
    fi

    echo -e "${CYAN}Checking Database Connection...${NC}"
    if docker compose exec -T airflow-webserver airflow db check >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Database connection successful"
    else
        echo "  ${RED}✗${NC} Database connection failed"
        all_healthy=false
    fi

    echo -e "${CYAN}Checking DAG Files...${NC}"
    local dag_count=$(docker compose exec -T airflow-webserver airflow dags list --output json | jq '. | length' 2>/dev/null || echo "0")
    if [ "$dag_count" -gt 0 ]; then
        echo "  ${GREEN}✓${NC} Found $dag_count DAG(s)"
    else
        echo "  ${RED}✗${NC} No DAGs found or error parsing DAGs"
        all_healthy=false
    fi

    if [ "$all_healthy" = true ]; then
        log_success "All orchestration health checks passed"
        return 0
    else
        log_error "Some orchestration health checks failed"
        return 1
    fi
}

# Quick Orchestration Status
quick_orchestration_status() {
    echo -e "${CYAN}🎯 Orchestration (Airflow):${NC}"

    local webserver_status="Unknown"
    local scheduler_status="Unknown"

    if curl -f http://localhost:8085/health >/dev/null 2>&1; then
        webserver_status="${GREEN}Running${NC}"
    else
        webserver_status="${RED}Stopped${NC}"
    fi

    if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
        scheduler_status="${GREEN}Running${NC}"
    else
        scheduler_status="${RED}Stopped${NC}"
    fi

    echo "  Webserver: $webserver_status"
    echo "  Scheduler: $scheduler_status"
}

# Initialize Airflow Database
init_airflow_db() {
    print_header "🔧 Initializing Airflow Database"

    log_info "Running Airflow database initialization..."
    docker compose run --rm airflow-init airflow db init

    log_info "Creating Airflow admin user..."
    docker compose run --rm airflow-init airflow users create \
        --username admin \
        --firstname Admin \
        --lastname User \
        --role Admin \
        --email admin@clinical-trials.local \
        --password admin

    log_success "Airflow database initialized"
}

# Export functions for use in main script
export -f start_orchestration
export -f stop_orchestration
export -f rebuild_orchestration
export -f check_airflow_health
export -f show_orchestration_status
export -f show_orchestration_urls
export -f run_orchestration_health_checks
export -f quick_orchestration_status
export -f init_airflow_db
