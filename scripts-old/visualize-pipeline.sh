#!/bin/bash
#
# Visual Pipeline Status - Shows hierarchical view of all services
#

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Unicode symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
BRANCH="├──"
LAST_BRANCH="└──"
PIPE="│"

# Get service status with health check
get_service_status() {
    local service=$1
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo "STOPPED"
        return
    fi
    
    # Check health status
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "none")
    
    if [ "$health" = "healthy" ]; then
        echo "HEALTHY"
    elif [ "$health" = "starting" ]; then
        echo "STARTING"
    elif [ "$health" = "unhealthy" ]; then
        echo "UNHEALTHY"
    else
        # No health check defined
        local state=$(docker inspect --format='{{.State.Status}}' "$service" 2>/dev/null || echo "unknown")
        if [ "$state" = "running" ]; then
            echo "RUNNING"
        else
            echo "STOPPED"
        fi
    fi
}

# Get colored status indicator
get_status_indicator() {
    local status=$1
    
    case "$status" in
        HEALTHY)
            echo -e "${GREEN}${CHECK}${NC}"
            ;;
        RUNNING)
            echo -e "${GREEN}${CHECK}${NC}"
            ;;
        STARTING)
            echo -e "${YELLOW}⧗${NC}"
            ;;
        UNHEALTHY)
            echo -e "${RED}⚠${NC}"
            ;;
        STOPPED)
            echo -e "${GRAY}${CROSS}${NC}"
            ;;
        *)
            echo -e "${GRAY}?${NC}"
            ;;
    esac
}

# Get service uptime
get_uptime() {
    local service=$1
    local started=$(docker inspect --format='{{.State.StartedAt}}' "$service" 2>/dev/null || echo "")
    
    if [ -z "$started" ]; then
        echo "N/A"
        return
    fi
    
    local start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
    local now_epoch=$(date +%s)
    local uptime_seconds=$((now_epoch - start_epoch))
    
    if [ $uptime_seconds -lt 60 ]; then
        echo "${uptime_seconds}s"
    elif [ $uptime_seconds -lt 3600 ]; then
        echo "$((uptime_seconds / 60))m"
    elif [ $uptime_seconds -lt 86400 ]; then
        echo "$((uptime_seconds / 3600))h"
    else
        echo "$((uptime_seconds / 86400))d"
    fi
}

# Get container memory usage
get_memory() {
    local service=$1
    docker stats --no-stream --format "{{.MemUsage}}" "$service" 2>/dev/null | cut -d'/' -f1 | xargs || echo "N/A"
}

# Draw service tree
draw_service() {
    local prefix=$1
    local service=$2
    local is_last=$3
    
    local status=$(get_service_status "$service")
    local indicator=$(get_status_indicator "$status")
    local uptime=$(get_uptime "$service")
    local memory=$(get_memory "$service")
    
    local branch=$BRANCH
    if [ "$is_last" = "true" ]; then
        branch=$LAST_BRANCH
    fi
    
    # Colorize service name based on status
    local service_color=$NC
    case "$status" in
        HEALTHY|RUNNING) service_color=$GREEN ;;
        STARTING) service_color=$YELLOW ;;
        UNHEALTHY) service_color=$RED ;;
        STOPPED) service_color=$GRAY ;;
    esac
    
    printf "${prefix}${branch} ${indicator} ${service_color}%-30s${NC} ${GRAY}[%8s]${NC} ${CYAN}%8s${NC} ${BLUE}%-10s${NC}\n" \
        "$service" "$status" "$uptime" "$memory"
}

# Clear screen
clear

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    Clinical MLOps - Pipeline Visualization                 ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Level 0: Infrastructure
echo -e "${CYAN}▶ Level 0: Infrastructure${NC} ${GRAY}(Core Services - Always Available)${NC}"
echo ""

services_l0=(
    "minio:false"
    "minio-setup:false"
    "zookeeper:false"
    "kafka:false"
    "kafka-ui:false"
    "postgres-mlflow:false"
    "postgres-airflow:false"
    "redis:false"
    "redis-insight:false"
    "mlflow-server:true"
)

for item in "${services_l0[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
done

# Count running services
l0_running=0
l0_total=10
for item in "${services_l0[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l0_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l0_running${NC}${GRAY}/${l0_total} services running${NC}"
echo ""

# Level 1: Data Ingestion
echo -e "${CYAN}▶ Level 1: Data Ingestion${NC} ${GRAY}(Profile: data-ingestion)${NC}"
echo ""

services_l1=(
    "kafka-producer:false"
    "kafka-consumer:false"
    "clinical-mq:false"
    "clinical-data-gateway:false"
    "lab-results-processor:false"
    "clinical-data-generator:true"
)

l1_running=0
l1_total=6
for item in "${services_l1[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l1_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l1_running${NC}${GRAY}/${l1_total} services running${NC}"
echo ""

# Level 2: Data Processing
echo -e "${CYAN}▶ Level 2: Data Processing${NC} ${GRAY}(Profile: data-processing)${NC}"
echo ""

services_l2=(
    "spark-master:false"
    "spark-worker:false"
    "spark-streaming:false"
    "spark-batch:true"
)

l2_running=0
l2_total=4
for item in "${services_l2[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l2_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l2_running${NC}${GRAY}/${l2_total} services running${NC}"
echo ""

# Level 3: Feature Engineering
echo -e "${CYAN}▶ Level 3: Feature Engineering${NC} ${GRAY}(Profile: features)${NC}"
echo ""

services_l3=(
    "feature-engineering:true"
)

l3_running=0
l3_total=1
for item in "${services_l3[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l3_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l3_running${NC}${GRAY}/${l3_total} services running${NC}"
echo ""

# Level 4: ML Pipeline
echo -e "${CYAN}▶ Level 4: ML Pipeline${NC} ${GRAY}(Profile: ml-pipeline)${NC}"
echo ""

services_l4=(
    "ml-training:false"
    "model-serving:true"
)

l4_running=0
l4_total=2
for item in "${services_l4[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l4_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l4_running${NC}${GRAY}/${l4_total} services running${NC}"
echo ""

# Level 5: Observability
echo -e "${CYAN}▶ Level 5: Observability${NC} ${GRAY}(Profile: observability)${NC}"
echo ""

services_l5=(
    "airflow-init:false"
    "airflow-webserver:false"
    "airflow-scheduler:false"
    "prometheus:false"
    "grafana:false"
    "monitoring-service:false"
    "opensearch:false"
    "opensearch-dashboards:false"
    "data-prepper:false"
    "filebeat:true"
)

l5_running=0
l5_total=10
for item in "${services_l5[@]}"; do
    IFS=':' read -r service is_last <<< "$item"
    draw_service "  " "$service" "$is_last"
    status=$(get_service_status "$service")
    if [ "$status" != "STOPPED" ]; then
        ((l5_running++))
    fi
done

echo -e "  ${GRAY}└── Status: ${GREEN}$l5_running${NC}${GRAY}/${l5_total} services running${NC}"
echo ""

# Summary
total_running=$((l0_running + l1_running + l2_running + l3_running + l4_running + l5_running))
total_services=$((l0_total + l1_total + l2_total + l3_total + l4_total + l5_total))

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                              Pipeline Summary                               ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

printf "  ${CYAN}Total Services:${NC}      ${GREEN}%d${NC} / ${GRAY}%d${NC} running (%.1f%%)\n" \
    $total_running $total_services $(echo "scale=1; $total_running * 100 / $total_services" | bc)

echo ""
echo "  ${CYAN}Levels Active:${NC}"
[ $l0_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 0: Infrastructure" || echo -e "    ${GRAY}${CROSS}${NC} Level 0: Infrastructure"
[ $l1_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 1: Data Ingestion" || echo -e "    ${GRAY}${CROSS}${NC} Level 1: Data Ingestion"
[ $l2_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 2: Data Processing" || echo -e "    ${GRAY}${CROSS}${NC} Level 2: Data Processing"
[ $l3_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 3: Feature Engineering" || echo -e "    ${GRAY}${CROSS}${NC} Level 3: Feature Engineering"
[ $l4_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 4: ML Pipeline" || echo -e "    ${GRAY}${CROSS}${NC} Level 4: ML Pipeline"
[ $l5_running -gt 0 ] && echo -e "    ${GREEN}${CHECK}${NC} Level 5: Observability" || echo -e "    ${GRAY}${CROSS}${NC} Level 5: Observability"

echo ""
echo "  ${CYAN}Access Points:${NC}"
[ $(get_service_status "minio") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} MinIO Console:      http://localhost:9001"
[ $(get_service_status "kafka-ui") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Kafka UI:           http://localhost:8090"
[ $(get_service_status "mlflow-server") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} MLflow:             http://localhost:5000"
[ $(get_service_status "redis-insight") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Redis Insight:      http://localhost:5540"
[ $(get_service_status "spark-master") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Spark Master:       http://localhost:8080"
[ $(get_service_status "model-serving") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Model API:          http://localhost:8000"
[ $(get_service_status "airflow-webserver") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Airflow:            http://localhost:8081"
[ $(get_service_status "prometheus") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Prometheus:         http://localhost:9090"
[ $(get_service_status "grafana") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} Grafana:            http://localhost:3000"
[ $(get_service_status "opensearch-dashboards") != "STOPPED" ] && echo -e "    ${GREEN}${ARROW}${NC} OpenSearch:         http://localhost:5601"

echo ""
echo "  ${CYAN}Quick Actions:${NC}"
echo "    ./manage_pipeline.sh --status           # Detailed status"
echo "    ./manage_pipeline.sh --start-level N    # Start level N"
echo "    ./manage_pipeline.sh --logs N           # Follow logs"
echo ""

# Calculate total memory usage
total_memory=$(docker stats --no-stream --format "{{.Container}} {{.MemUsage}}" 2>/dev/null | \
    grep -E 'kafka|spark|minio|mlflow|redis|clinical|airflow|prometheus|grafana|opensearch' | \
    awk '{print $2}' | sed 's/MiB//' | sed 's/GiB/*1024/' | \
    awk '{sum+=$1} END {printf "%.1f", sum}')

echo "  ${CYAN}Resource Usage:${NC}"
echo "    Memory: ${total_memory} MiB"
echo ""