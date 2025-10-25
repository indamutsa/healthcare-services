#!/bin/bash
#
# Orchestration Health Checks for Clinical MLOps Platform
# Provides detailed health monitoring for Airflow services
#
# Note: Common utilities must be sourced before this script

set -e

# Detailed Airflow component checks
check_airflow_webserver() {
    local component="Airflow Webserver"
    local url="http://localhost:8085"

    echo -e "${CYAN}Checking $component...${NC}"

    # Basic connectivity
    if ! curl -f "$url/health" >/dev/null 2>&1; then
        echo "  ${RED}✗${NC} Health endpoint not responding"
        return 1
    fi

    # Check if serving UI
    if curl -s "$url" | grep -q "Airflow"; then
        echo "  ${GREEN}✓${NC} UI serving correctly"
    else
        echo "  ${YELLOW}⚠${NC} UI not responding properly"
    fi

    # Check API endpoints
    if curl -f "$url/api/v1/dags" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} API endpoints accessible"
    else
        echo "  ${RED}✗${NC} API endpoints not accessible"
        return 1
    fi

    return 0
}

check_airflow_scheduler() {
    local component="Airflow Scheduler"

    echo -e "${CYAN}Checking $component...${NC}"

    # Check if scheduler job is running
    if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Scheduler job running"
    else
        echo "  ${RED}✗${NC} Scheduler job not running"
        return 1
    fi

    # Check scheduler logs for recent activity
    local recent_activity=$(docker compose logs --since=5m airflow-scheduler 2>/dev/null | grep -c "heartbeat\|DAG\|Task" || echo "0")
    if [ "$recent_activity" -gt 0 ]; then
        echo "  ${GREEN}✓${NC} Recent scheduler activity detected"
    else
        echo "  ${YELLOW}⚠${NC} No recent scheduler activity"
    fi

    return 0
}

check_airflow_database() {
    local component="Airflow Database"

    echo -e "${CYAN}Checking $component...${NC}"

    # Check database connectivity from webserver
    if docker compose exec -T airflow-webserver airflow db check >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Database connection successful"
    else
        echo "  ${RED}✗${NC} Database connection failed"
        return 1
    fi

    # Check if PostgreSQL container is healthy
    if docker compose ps postgres-airflow --format "{{.Status}}" | grep -q "Up\|healthy"; then
        echo "  ${GREEN}✓${NC} PostgreSQL container running"
    else
        echo "  ${RED}✗${NC} PostgreSQL container not running"
        return 1
    fi

    return 0
}

check_airflow_dags() {
    local component="Airflow DAGs"

    echo -e "${CYAN}Checking $component...${NC}"

    # List DAGs and check for parsing errors
    local dag_output=$(docker compose exec -T airflow-webserver airflow dags list --output json 2>/dev/null)

    if [ $? -eq 0 ]; then
        local dag_count=$(echo "$dag_output" | jq '. | length' 2>/dev/null || echo "0")
        echo "  ${GREEN}✓${NC} Found $dag_count DAG(s)"

        # Check for paused/unpaused status
        local active_count=$(echo "$dag_output" | jq '[.[] | select(.is_paused == false)] | length' 2>/dev/null || echo "0")
        local paused_count=$(echo "$dag_output" | jq '[.[] | select(.is_paused == true)] | length' 2>/dev/null || echo "0")

        if [ "$active_count" -gt 0 ]; then
            echo "  ${GREEN}✓${NC} $active_count active DAG(s)"
        fi

        if [ "$paused_count" -gt 0 ]; then
            echo "  ${YELLOW}⚠${NC} $paused_count paused DAG(s)"
        fi

        # List specific DAGs we expect
        echo "  📋 Available DAGs:"
        echo "$dag_output" | jq -r '.[] | "    - \(.dag_id) (\(.file_loc))"' 2>/dev/null || echo "    Unable to parse DAG details"

    else
        echo "  ${RED}✗${NC} Failed to list DAGs"
        return 1
    fi

    return 0
}

check_airflow_plugins() {
    local component="Airflow Plugins"

    echo -e "${CYAN}Checking $component...${NC}"

    # Check if plugins directory is mounted
    if docker compose exec -T airflow-webserver test -d /opt/airflow/plugins; then
        echo "  ${GREEN}✓${NC} Plugins directory mounted"

        # List custom plugins
        local plugin_count=$(docker compose exec -T airflow-webserver find /opt/airflow/plugins -name "*.py" -type f | wc -l)
        if [ "$plugin_count" -gt 0 ]; then
            echo "  ${GREEN}✓${NC} Found $plugin_count plugin file(s)"
            docker compose exec -T airflow-webserver find /opt/airflow/plugins -name "*.py" -type f -exec basename {} \; | sed 's/^/    - /'
        else
            echo "  ${YELLOW}⚠${NC} No plugin files found"
        fi
    else
        echo "  ${RED}✗${NC} Plugins directory not accessible"
        return 1
    fi

    return 0
}

check_airflow_connections() {
    local component="Airflow Connections"

    echo -e "${CYAN}Checking $component...${NC}"

    # Check if connections from config are loaded
    local expected_connections=("kafka_clinical" "mlflow_tracking" "redis_features" "minio_storage" "spark_cluster")
    local missing_connections=()

    for conn_id in "${expected_connections[@]}"; do
        if docker compose exec -T airflow-webserver airflow connections get "$conn_id" >/dev/null 2>&1; then
            echo "  ${GREEN}✓${NC} Connection '$conn_id' configured"
        else
            echo "  ${RED}✗${NC} Connection '$conn_id' missing"
            missing_connections+=("$conn_id")
        fi
    done

    if [ ${#missing_connections[@]} -gt 0 ]; then
        echo "  ${YELLOW}⚠${NC} Missing connections: ${missing_connections[*]}"
        echo "  💡 Run: docker compose run --rm airflow-init airflow connections import /opt/airflow/config/connections.yaml"
    fi

    return 0
}

check_airflow_system_resources() {
    local component="System Resources"

    echo -e "${CYAN}Checking $component...${NC}"

    # Check container resource usage
    for service in "airflow-webserver" "airflow-scheduler"; do
        local stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" "$service" 2>/dev/null)
        if [ -n "$stats" ]; then
            echo "  📊 $service resource usage:"
            echo "$stats" | tail -n +2 | sed 's/^/    /'
        fi
    done

    # Check disk space for logs
    local log_usage=$(docker compose exec -T airflow-webserver du -sh /opt/airflow/logs 2>/dev/null || echo "Unknown")
    echo "  💾 Log directory usage: $log_usage"

    return 0
}

# Main orchestration health check function
run_orchestration_health_checks() {
    print_header "🏥 Comprehensive Orchestration Health Checks"

    local overall_status=0
    local checks=(
        "check_airflow_webserver"
        "check_airflow_scheduler"
        "check_airflow_database"
        "check_airflow_dags"
        "check_airflow_plugins"
        "check_airflow_connections"
        "check_airflow_system_resources"
    )

    for check_func in "${checks[@]}"; do
        echo ""
        if $check_func; then
            echo "  ${GREEN}✓${NC} $check_func passed"
        else
            echo "  ${RED}✗${NC} $check_func failed"
            overall_status=1
        fi
    done

    echo ""
    if [ $overall_status -eq 0 ]; then
        log_success "All orchestration health checks passed"
    else
        log_error "Some orchestration health checks failed"
    fi

    return $overall_status
}

# Quick health check for orchestration
quick_orchestration_health() {
    echo -e "${CYAN}🎯 Orchestration Health Check:${NC}"

    local issues=()

    # Quick webserver check
    if curl -f http://localhost:8085/health >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Webserver: Healthy"
    else
        echo "  ${RED}✗${NC} Webserver: Unhealthy"
        issues+=("webserver")
    fi

    # Quick scheduler check
    if docker compose exec -T airflow-scheduler airflow jobs check --job-type SchedulerJob --hostname airflow-scheduler >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Scheduler: Healthy"
    else
        echo "  ${RED}✗${NC} Scheduler: Unhealthy"
        issues+=("scheduler")
    fi

    # Quick DAG check
    local dag_count=$(docker compose exec -T airflow-webserver airflow dags list --output json 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    if [ "$dag_count" -gt 0 ]; then
        echo "  ${GREEN}✓${NC} DAGs: $dag_count loaded"
    else
        echo "  ${RED}✗${NC} DAGs: None loaded"
        issues+=("dags")
    fi

    if [ ${#issues[@]} -eq 0 ]; then
        return 0
    else
        echo "  ${YELLOW}⚠${NC} Issues detected: ${issues[*]}"
        return 1
    fi
}

# Export functions
export -f run_orchestration_health_checks
export -f quick_orchestration_health
export -f check_airflow_webserver
export -f check_airflow_scheduler
export -f check_airflow_database
export -f check_airflow_dags
export -f check_airflow_plugins
export -f check_airflow_connections
export -f check_airflow_system_resources