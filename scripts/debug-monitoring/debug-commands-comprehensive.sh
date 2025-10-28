#!/bin/bash
#
# Debug Commands Module - Comprehensive Version
# Debugging and troubleshooting utilities for Clinical Trials Service
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Debug levels with cascading behavior
DEBUG_LEVELS=(
    "system-status"
    "service-health"
    "resource-monitoring"
    "network-analysis"
    "data-flow"
    "performance-deep-dive"
)

# Get debug levels to run (cascading behavior)
get_debug_levels() {
    local target_level=$1
    local -a levels_to_run=()
    
    for ((i=0; i<=target_level; i++)); do
        levels_to_run+=("${DEBUG_LEVELS[$i]}")
    done
    
    printf "%s\n" "${levels_to_run[@]}"
}

# Print debug header
print_debug_header() {
    local level_name=$1
    echo -e "\n${CYAN}Debug Level: $level_name${NC}"
    echo "================================"
}

# Check if Docker is available
check_docker_availability() {
    if ! command -v docker > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not available${NC}"
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        return 1
    fi
    
    return 0
}

# Level 0: System Status
debug_system_status() {
    print_debug_header "System Status"
    
    echo -e "${BLUE}System Overview${NC}"
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    echo -e "${BLUE}Docker System${NC}"
    docker system df
    echo ""
    
    echo -e "${BLUE}Container Status${NC}"
    docker-compose ps
    echo ""
    
    echo -e "${BLUE}Service Summary${NC}"
    local running_count=$(docker-compose ps --services --filter "status=running" | wc -l)
    local total_count=$(docker-compose ps --services | wc -l)
    echo "Running: $running_count/$total_count services"
    
    if [ "$running_count" -eq "$total_count" ]; then
        echo -e "${GREEN}All services are running${NC}"
    else
        echo -e "${YELLOW}Some services are not running${NC}"
    fi
}

# Level 1: Service Health
debug_service_health() {
    print_debug_header "Service Health"
    
    echo -e "${BLUE}Infrastructure Services${NC}"
    
    # MinIO
    if curl -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo -e "  MinIO: ${GREEN}Healthy${NC}"
    else
        echo -e "  MinIO: ${RED}Unhealthy${NC}"
    fi
    
    # PostgreSQL
    if docker exec postgres-mlflow pg_isready -U postgres > /dev/null 2>&1; then
        echo -e "  PostgreSQL: ${GREEN}Healthy${NC}"
    else
        echo -e "  PostgreSQL: ${RED}Unhealthy${NC}"
    fi
    
    # Redis
    if docker exec redis redis-cli ping > /dev/null 2>&1; then
        echo -e "  Redis: ${GREEN}Healthy${NC}"
    else
        echo -e "  Redis: ${RED}Unhealthy${NC}"
    fi
    
    # Kafka
    if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
        echo -e "  Kafka: ${GREEN}Healthy${NC}"
    else
        echo -e "  Kafka: ${RED}Unhealthy${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Clinical Services${NC}"
    
    # Clinical Gateway
    if curl -s http://localhost:8082/actuator/health > /dev/null 2>&1; then
        echo -e "  Clinical Gateway: ${GREEN}Healthy${NC}"
    else
        echo -e "  Clinical Gateway: ${RED}Unhealthy${NC}"
    fi
    
    # Lab Processor
    if curl -s http://localhost:8083/actuator/health > /dev/null 2>&1; then
        echo -e "  Lab Processor: ${GREEN}Healthy${NC}"
    else
        echo -e "  Lab Processor: ${RED}Unhealthy${NC}"
    fi
    
    # IBM MQ
    if docker ps | grep -q clinical-mq && docker exec clinical-mq dspmq 2>/dev/null | grep -q "STATUS(Running)"; then
        echo -e "  IBM MQ: ${GREEN}Healthy${NC}"
    else
        echo -e "  IBM MQ: ${RED}Unhealthy${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Processing Services${NC}"
    
    # Spark Master
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "  Spark Master: ${GREEN}Healthy${NC}"
    else
        echo -e "  Spark Master: ${RED}Unhealthy${NC}"
    fi
    
    # Spark Worker
    if curl -s http://localhost:8081 > /dev/null 2>&1; then
        echo -e "  Spark Worker: ${GREEN}Healthy${NC}"
    else
        echo -e "  Spark Worker: ${RED}Unhealthy${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Monitoring Services${NC}"
    
    # Prometheus
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo -e "  Prometheus: ${GREEN}Healthy${NC}"
    else
        echo -e "  Prometheus: ${RED}Unhealthy${NC}"
    fi
    
    # Grafana
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        echo -e "  Grafana: ${GREEN}Healthy${NC}"
    else
        echo -e "  Grafana: ${RED}Unhealthy${NC}"
    fi
}

# Level 2: Resource Monitoring
debug_resource_monitoring() {
    print_debug_header "Resource Monitoring"
    
    echo -e "${BLUE}Container Resource Usage${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    echo ""
    
    echo -e "${BLUE}System Resources${NC}"
    echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2 " (" $5 ")"})'"
    echo "Disk: $(df -h / | awk 'NR==2{print $3"/"$2 " (" $5 ")"})'"
}

# Level 3: Network Analysis
debug_network_analysis() {
    print_debug_header "Network Analysis"
    
    echo -e "${BLUE}Network Connectivity${NC}"
    
    # Docker networks
    if docker network inspect clinical-trials-service_mlops-network > /dev/null 2>&1; then
        echo -e "  Docker Network: ${GREEN}Available${NC}"
    else
        echo -e "  Docker Network: ${RED}Not Available${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Port Status${NC}"
    local ports=(
        "8082:Clinical Gateway"
        "8083:Lab Processor"
        "8080:Spark Master"
        "8081:Spark Worker"
        "5432:PostgreSQL MLflow"
        "5433:PostgreSQL Airflow"
        "6379:Redis"
        "9000:MinIO"
        "9090:Prometheus"
        "3000:Grafana"
        "1414:IBM MQ"
        "9443:IBM MQ Web"
    )
    
    for port_info in "${ports[@]}"; do
        port=$(echo "$port_info" | cut -d: -f1)
        service=$(echo "$port_info" | cut -d: -f2)
        
        if ss -tulpn 2>/dev/null | grep ":$port " > /dev/null 2>&1; then
            echo -e "  $service ($port): ${GREEN}Listening${NC}"
        else
            echo -e "  $service ($port): ${RED}Not Listening${NC}"
        fi
    done
}

# Level 4: Data Flow Analysis
debug_data_flow() {
    print_debug_header "Data Flow Analysis"
    
    echo -e "${BLUE}Message Queue Status${NC}"
    
    # IBM MQ queues
    if docker ps | grep -q clinical-mq; then
        echo -e "  IBM MQ: ${GREEN}Running${NC}"
    else
        echo -e "  ${YELLOW}IBM MQ not running${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Kafka Data Flow${NC}"
    
    if docker ps | grep -q kafka; then
        echo -e "  Kafka Topics:"
        docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null
    else
        echo -e "  ${YELLOW}Kafka not running${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Spark Processing${NC}"
    
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "  Spark Master: ${GREEN}Accessible${NC}"
    else
        echo -e "  ${YELLOW}Spark Master not accessible${NC}"
    fi
}

# Level 5: Performance Deep Dive
debug_performance_deep_dive() {
    print_debug_header "Performance Deep Dive"
    
    echo -e "${BLUE}Performance Metrics${NC}"
    
    echo -e "  ${CYAN}Real-time Resource Usage (5 seconds):${NC}"
    timeout 5s docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" || true
    
    echo ""
    
    echo -e "${BLUE}System Performance${NC}"
    
    local load=$(uptime | awk -F'load average:' '{print $2}')
    echo "  Load Average: $load"
}

# Main Debug Function
run_debug_commands() {
    local target_level=$1
    
    if [ -z "$target_level" ] || [ "$target_level" -lt 0 ] || [ "$target_level" -gt 5 ]; then
        echo -e "${RED}Error: Invalid debug level. Must be 0-5${NC}"
        return 1
    fi
    
    if ! check_docker_availability; then
        return 1
    fi
    
    echo -e "${CYAN}Debug Commands - Level $target_level${NC}"
    echo "========================================"
    echo "Timestamp: $(date)"
    echo "Target Level: $target_level"
    
    local -a debug_levels
    mapfile -t debug_levels < <(get_debug_levels "$target_level")
    
    echo "Debug Levels: ${debug_levels[*]}"
    echo ""
    
    for level in "${debug_levels[@]}"; do
        case "$level" in
            "system-status")
                debug_system_status
                ;;
            "service-health")
                debug_service_health
                ;;
            "resource-monitoring")
                debug_resource_monitoring
                ;;
            "network-analysis")
                debug_network_analysis
                ;;
            "data-flow")
                debug_data_flow
                ;;
            "performance-deep-dive")
                debug_performance_deep_dive
                ;;
        esac
        
        if [ "$level" != "${debug_levels[-1]}" ]; then
            echo ""
            echo "---"
            echo ""
        fi
    done
    
    echo -e "${GREEN}Debug commands completed${NC}"
}

export -f run_debug_commands