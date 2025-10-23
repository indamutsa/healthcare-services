#!/bin/bash
#
# Clinical MLOps Pipeline Manager - Clean Level-Based Architecture
# CASCADE STOP: Stopping level N stops N, N-1, ..., 0
#

set -e

# --- Colors ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Level Definitions ---
declare -A LEVEL_SERVICES
declare -A LEVEL_PROFILES
declare -A LEVEL_NAMES
declare -A LEVEL_DEPENDENCIES

# Level 0: Infrastructure (NO mlflow-server - moved to Level 4)
LEVEL_SERVICES[0]="minio minio-setup postgres-mlflow postgres-airflow redis redis-insight zookeeper kafka kafka-ui"
LEVEL_PROFILES[0]=""
LEVEL_NAMES[0]="Infrastructure"
LEVEL_DEPENDENCIES[0]=""

# Level 1: Data Ingestion
LEVEL_SERVICES[1]="kafka-producer kafka-consumer clinical-mq clinical-data-gateway lab-results-processor clinical-data-generator"
LEVEL_PROFILES[1]="data-ingestion"
LEVEL_NAMES[1]="Data Ingestion"
LEVEL_DEPENDENCIES[1]="0"

# Level 2: Data Processing
LEVEL_SERVICES[2]="spark-master spark-worker spark-streaming spark-batch"
LEVEL_PROFILES[2]="data-processing"
LEVEL_NAMES[2]="Data Processing"
LEVEL_DEPENDENCIES[2]="0 1"

# Level 3: Feature Engineering
LEVEL_SERVICES[3]="feature-engineering"
LEVEL_PROFILES[3]="features"
LEVEL_NAMES[3]="Feature Engineering"
LEVEL_DEPENDENCIES[3]="0 1 2"

# Level 4: ML Pipeline (NOW includes mlflow-server)
LEVEL_SERVICES[4]="mlflow-server ml-training model-serving"
LEVEL_PROFILES[4]="ml-pipeline"
LEVEL_NAMES[4]="ML Pipeline"
LEVEL_DEPENDENCIES[4]="0 1 2 3"

# Level 5: Observability
LEVEL_SERVICES[5]="airflow-init airflow-webserver airflow-scheduler prometheus grafana monitoring-service opensearch opensearch-dashboards data-prepper filebeat"
LEVEL_PROFILES[5]="observability"
LEVEL_NAMES[5]="Observability"
LEVEL_DEPENDENCIES[5]="0 1 2 3 4"

MAX_LEVEL=5

# --- Helper Functions ---

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_level_header() {
    local level=$1
    local action=$2
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Level $level: ${LEVEL_NAMES[$level]} ($action)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_service_running() {
    local service=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        return 0
    else
        return 1
    fi
}

check_level_running() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    local all_running=true
    
    for service in $services; do
        if ! check_service_running "$service"; then
            all_running=false
            break
        fi
    done
    
    if [ "$all_running" = true ]; then
        return 0
    else
        return 1
    fi
}

get_level_status() {
    local level=$1
    if check_level_running $level; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${RED}✗ STOPPED${NC}"
    fi
}

start_level() {
    local level=$1
    local force_restart=${2:-false}
    
    print_level_header $level "Starting"
    
    # Check dependencies
    local deps="${LEVEL_DEPENDENCIES[$level]}"
    for dep in $deps; do
        if ! check_level_running $dep; then
            echo -e "${YELLOW}  ⚠️  Dependency: Level $dep (${LEVEL_NAMES[$dep]}) not running${NC}"
            echo -e "${YELLOW}  → Auto-starting Level $dep...${NC}"
            start_level $dep
        else
            echo -e "${GREEN}  ✓ Dependency: Level $dep (${LEVEL_NAMES[$dep]}) running${NC}"
        fi
    done
    
    # Start services
    local services="${LEVEL_SERVICES[$level]}"
    local profile="${LEVEL_PROFILES[$level]}"
    
    echo ""
    echo "  Services to start:"
    for service in $services; do
        if check_service_running "$service"; then
            if [ "$force_restart" = true ]; then
                echo -e "    • $service ${YELLOW}[RESTARTING]${NC}"
            else
                echo -e "    • $service ${GREEN}[ALREADY RUNNING]${NC}"
            fi
        else
            echo -e "    • $service ${BLUE}[STARTING]${NC}"
        fi
    done
    
    echo ""
    
    # Execute docker compose
    if [ -n "$profile" ]; then
        if [ "$force_restart" = true ]; then
            docker compose --profile "$profile" up -d --force-recreate $services
        else
            docker compose --profile "$profile" up -d $services
        fi
    else
        # Level 0 has no profile
        if [ "$force_restart" = true ]; then
            docker compose up -d --force-recreate $services
        else
            docker compose up -d $services
        fi
    fi
    
    echo ""
    echo -e "${GREEN}  ✓ Level $level started${NC}"
}

stop_level_only() {
    # Stop only this specific level without cascade
    local level=$1
    local remove_volumes=${2:-false}
    
    local services="${LEVEL_SERVICES[$level]}"
    
    echo "  Stopping and removing containers:"
    for service in $services; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
            echo -e "    • $service ${YELLOW}[REMOVING]${NC}"
            docker stop "$service" > /dev/null 2>&1 || true
            docker rm "$service" > /dev/null 2>&1 || true
        else
            echo -e "    • $service ${BLUE}[NOT RUNNING]${NC}"
        fi
    done
    
    if [ "$remove_volumes" = true ]; then
        echo ""
        echo "  Removing volumes for level $level:"
        # Get volumes associated with these services
        for service in $services; do
            local volumes=$(docker volume ls --format '{{.Name}}' | grep -E "${service}|level-${level}" || true)
            if [ -n "$volumes" ]; then
                echo "$volumes" | while read vol; do
                    echo -e "    • $vol ${RED}[REMOVING]${NC}"
                    docker volume rm "$vol" > /dev/null 2>&1 || true
                done
            fi
        done
    fi
}

stop_level() {
    # CASCADE STOP: Stop this level and all lower levels (N → 0)
    local level=$1
    local remove_volumes=${2:-false}
    
    print_header "🔻 Cascade Stop: Level $level → 0"
    
    echo -e "${YELLOW}This will stop levels: $level"
    for l in $(seq $(($level - 1)) -1 0); do
        echo -n ", $l"
    done
    echo -e "${NC}"
    echo ""
    
    # Stop from current level down to 0
    for current_level in $(seq $level -1 0); do
        print_level_header $current_level "Stopping"
        stop_level_only $current_level $remove_volumes
        echo ""
        echo -e "${GREEN}  ✓ Level $current_level stopped${NC}"
    done
    
    echo ""
    echo -e "${GREEN}✓ Cascade stop complete (Levels $level → 0 stopped)${NC}"
}

restart_level() {
    local level=$1
    
    print_level_header $level "Restarting"
    
    stop_level_only $level false
    sleep 2
    start_level $level true
    
    echo -e "${GREEN}  ✓ Level $level restarted${NC}"
}

start_full_stack() {
    print_header "Starting Full Stack (All Levels)"
    
    for level in $(seq 0 $MAX_LEVEL); do
        start_level $level
    done
    
    echo ""
    echo -e "${GREEN}✓ Full stack started${NC}"
}

stop_full_stack() {
    print_header "Stopping Full Stack (All Levels)"
    
    # Stop in reverse order
    for level in $(seq $MAX_LEVEL -1 0); do
        stop_level_only $level false
    done
    
    echo ""
    echo -e "${GREEN}✓ Full stack stopped${NC}"
}

full_clean() {
    print_header "⚠️  FULL CLEANUP - REMOVING EVERYTHING FROM DOCKER COMPOSE"
    
    echo -e "${RED}This will remove:${NC}"
    echo "  • All containers defined in docker-compose"
    echo "  • All volumes defined in docker-compose"
    echo "  • All networks defined in docker-compose"
    echo "  • All images defined in docker-compose"
    echo ""
    echo -e "${YELLOW}Note: Only removes resources from this docker-compose file${NC}"
    echo ""
    read -p "Are you sure? Type 'yes' to continue: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Cleanup cancelled${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}→ Stopping all containers...${NC}"
    docker compose down --remove-orphans 2>/dev/null || true
    
    echo -e "${YELLOW}→ Removing all volumes...${NC}"
    docker compose down -v 2>/dev/null || true
    
    echo -e "${YELLOW}→ Removing all project containers (forced)...${NC}"
    for level in $(seq 0 $MAX_LEVEL); do
        local services="${LEVEL_SERVICES[$level]}"
        for service in $services; do
            if docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
                echo "    • Removing $service"
                docker rm -f "$service" > /dev/null 2>&1 || true
            fi
        done
    done
    
    echo -e "${YELLOW}→ Removing all named volumes from docker-compose...${NC}"
    # List of volumes from docker-compose
    local volumes="minio-data postgres-mlflow-data postgres-airflow-data kafka-data zookeeper-data"
    volumes="$volumes prometheus-data grafana-data redis-data spark-logs elasticsearch-data"
    volumes="$volumes logstash-data redis-insight-data feature-data"
    
    for vol in $volumes; do
        if docker volume ls --format '{{.Name}}' | grep -q "^${vol}$\|_${vol}$"; then
            echo "    • Removing volume: $vol"
            docker volume rm -f "$vol" > /dev/null 2>&1 || true
            # Also try with project prefix
            docker volume rm -f "clinical-trials-service_${vol}" > /dev/null 2>&1 || true
        fi
    done
    
    echo -e "${YELLOW}→ Removing project networks...${NC}"
    local network="mlops-network"
    if docker network ls --format '{{.Name}}' | grep -q "^${network}$\|_${network}$"; then
        echo "    • Removing network: $network"
        docker network rm "$network" > /dev/null 2>&1 || true
        docker network rm "clinical-trials-service_${network}" > /dev/null 2>&1 || true
    fi
    
    echo -e "${YELLOW}→ Removing all images defined in docker-compose...${NC}"
    
    # Get all images used in docker-compose
    local images=$(docker compose config 2>/dev/null | grep 'image:' | awk '{print $2}' | sort -u || true)
    
    # Also get built images
    for level in $(seq 0 $MAX_LEVEL); do
        local services="${LEVEL_SERVICES[$level]}"
        for service in $services; do
            # Try to get image ID
            local img=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "clinical.*${service}|${service}" | head -n 1 || true)
            if [ -n "$img" ]; then
                images="$images $img"
            fi
        done
    done
    
    # Remove duplicates and remove images
    if [ -n "$images" ]; then
        echo "$images" | tr ' ' '\n' | sort -u | while read img; do
            if [ -n "$img" ] && [ "$img" != " " ]; then
                echo "    • Removing image: $img"
                docker rmi -f "$img" > /dev/null 2>&1 || true
            fi
        done
    fi
    
    echo -e "${YELLOW}→ Final cleanup (dangling resources)...${NC}"
    docker system prune -f > /dev/null 2>&1 || true
    
    echo ""
    echo -e "${GREEN}✓ Full cleanup complete!${NC}"
    echo ""
    echo "Everything has been removed. To rebuild:"
    echo "  ./manage_pipeline.sh --start-level 0"
}

show_status() {
    print_header "Clinical MLOps - Pipeline Status"
    
    local total_running=0
    local total_services=0
    
    for level in $(seq 0 $MAX_LEVEL); do
        local services="${LEVEL_SERVICES[$level]}"
        local service_count=$(echo $services | wc -w)
        local running_count=0
        
        echo -e "${CYAN}Level $level: ${LEVEL_NAMES[$level]}${NC}"
        
        for service in $services; do
            ((total_services++))
            if check_service_running "$service"; then
                echo -e "  ${GREEN}✓${NC} $service"
                ((running_count++))
                ((total_running++))
            else
                echo -e "  ${RED}✗${NC} $service"
            fi
        done
        
        echo -e "  Status: $running_count/$service_count services running"
        echo ""
    done
    
    echo "=========================================="
    echo -e "Overall Status: $total_running/$total_services services running"
    echo "=========================================="
    echo ""
    
    # Show access points for running services
    echo "Access Points:"
    echo "----------------------------------------"
    
    if check_service_running "minio"; then
        echo -e "  ${GREEN}MinIO Console:${NC}    http://localhost:9001"
    fi
    if check_service_running "kafka-ui"; then
        echo -e "  ${GREEN}Kafka UI:${NC}         http://localhost:8090"
    fi
    if check_service_running "mlflow-server"; then
        echo -e "  ${GREEN}MLflow UI:${NC}        http://localhost:5000"
    fi
    if check_service_running "redis-insight"; then
        echo -e "  ${GREEN}Redis UI:${NC}         http://localhost:5540"
    fi
    if check_service_running "spark-master"; then
        echo -e "  ${GREEN}Spark Master:${NC}     http://localhost:8080"
    fi
    if check_service_running "model-serving"; then
        echo -e "  ${GREEN}Model API:${NC}        http://localhost:8000"
    fi
    if check_service_running "airflow-webserver"; then
        echo -e "  ${GREEN}Airflow UI:${NC}       http://localhost:8081"
    fi
    if check_service_running "prometheus"; then
        echo -e "  ${GREEN}Prometheus:${NC}       http://localhost:9090"
    fi
    if check_service_running "grafana"; then
        echo -e "  ${GREEN}Grafana:${NC}          http://localhost:3000"
    fi
    if check_service_running "opensearch-dashboards"; then
        echo -e "  ${GREEN}OpenSearch:${NC}       http://localhost:5601"
    fi
    
    echo ""
}

show_logs() {
    local level=$1
    
    if [ -z "$level" ]; then
        echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
        exit 1
    fi
    
    if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
        echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
        exit 1
    fi
    
    local services="${LEVEL_SERVICES[$level]}"
    
    print_level_header $level "Logs"
    
    echo "Following logs for:"
    for service in $services; do
        echo "  • $service"
    done
    echo ""
    
    docker compose logs -f $services
}

usage() {
    cat << EOF
${CYAN}Clinical MLOps Pipeline Manager${NC}

${GREEN}Usage:${NC}
  $0 [option]

${GREEN}Options:${NC}
  -s, --start-level <N>      Start level N and its dependencies
  -x, --stop-level <N>       Stop level N + cascade (N→0, keeps volumes)
  -X, --stop-level-full <N>  Stop level N + cascade (N→0, removes volumes)
  -r, --restart-level <N>    Restart level N only
  -l, --logs <N>             Follow logs for level N
  
  --start-full               Start all levels (0-5)
  --stop-full                Stop all levels (removes containers, keeps volumes)
  
  --status                   Show status of all levels
  
  --clean-all                Full cleanup (removes EVERYTHING including images)
  
  -h, --help                 Show this help message

${GREEN}Examples:${NC}
  # Start infrastructure only
  $0 --start-level 0
  
  # Start data ingestion (auto-starts level 0)
  $0 --start-level 1
  
  # Start ML Pipeline (auto-starts levels 0, 1, 2, 3)
  $0 --start-level 4
  
  # Stop data processing + cascade (stops 2, 1, 0)
  $0 --stop-level 2
  
  # Stop feature engineering + cascade with volumes (stops 3, 2, 1, 0)
  $0 --stop-level-full 3
  
  # Start everything
  $0 --start-full
  
  # Show status
  $0 --status
  
  # View logs for data processing
  $0 --logs 2
  
  # Full cleanup (removes everything)
  $0 --clean-all

${GREEN}Level Architecture:${NC}
  ${CYAN}Level 0: Infrastructure${NC}
    • minio, postgres (mlflow/airflow), redis, kafka, zookeeper
    • ${YELLOW}Note: MLflow server moved to Level 4${NC}
  
  ${CYAN}Level 1: Data Ingestion${NC}
    • kafka-producer, kafka-consumer, clinical-mq, data-gateway
    • Depends on: Level 0
  
  ${CYAN}Level 2: Data Processing${NC}
    • spark-master, spark-worker, spark-streaming, spark-batch
    • Depends on: Levels 0, 1
  
  ${CYAN}Level 3: Feature Engineering${NC}
    • feature-engineering
    • Depends on: Levels 0, 1, 2
  
  ${CYAN}Level 4: ML Pipeline${NC}
    • ${YELLOW}mlflow-server${NC}, ml-training, model-serving
    • Depends on: Levels 0, 1, 2, 3
  
  ${CYAN}Level 5: Observability${NC}
    • airflow, prometheus, grafana, opensearch
    • Depends on: Levels 0, 1, 2, 3, 4

${YELLOW}Important Notes:${NC}
  • ${GREEN}CASCADE STOP:${NC} --stop-level N stops N, N-1, ..., 0
    Example: --stop-level 3 stops levels 3, 2, 1, 0
  
  • --stop-level removes containers but keeps volumes (for data persistence)
  • --stop-level-full removes containers AND volumes (clean slate)
  • --clean-all removes EVERYTHING including images (nuclear option)
  • Starting a level automatically starts its dependencies
  • ${YELLOW}MLflow server is now in Level 4 (ML Pipeline), not Level 0${NC}

${CYAN}Cascade Stop Behavior:${NC}
  --stop-level 5  →  Stops 5, 4, 3, 2, 1, 0
  --stop-level 4  →  Stops 4, 3, 2, 1, 0
  --stop-level 3  →  Stops 3, 2, 1, 0
  --stop-level 2  →  Stops 2, 1, 0
  --stop-level 1  →  Stops 1, 0
  --stop-level 0  →  Stops 0 only

EOF
}

# --- Main Script ---

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

case "$1" in
    -s|--start-level)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
            exit 1
        fi
        
        level=$2
        
        if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
            echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
            exit 1
        fi
        
        start_level $level
        ;;
        
    -x|--stop-level)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
            exit 1
        fi
        
        level=$2
        
        if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
            echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
            exit 1
        fi
        
        stop_level $level false
        ;;
        
    -X|--stop-level-full)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
            exit 1
        fi
        
        level=$2
        
        if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
            echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
            exit 1
        fi
        
        stop_level $level true
        ;;
        
    -r|--restart-level)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
            exit 1
        fi
        
        level=$2
        
        if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
            echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
            exit 1
        fi
        
        restart_level $level
        ;;
        
    -l|--logs)
        show_logs "$2"
        ;;
        
    --start-full)
        start_full_stack
        ;;
        
    --stop-full)
        stop_full_stack
        ;;
        
    --status)
        show_status
        ;;
        
    --clean-all)
        full_clean
        ;;
        
    -h|--help)
        usage
        ;;
        
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  • View status:    ./manage_pipeline.sh --status"
echo "  • Follow logs:    ./manage_pipeline.sh --logs <level>"
echo "  • Check services: docker ps"
echo ""