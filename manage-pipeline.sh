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

start_level_rebuild() {
    # FRESH START: Stop cascade, rebuild images, force recreate
    local level=$1
    
    print_header "🔄 Fresh Start: Rebuild & Force Recreate Level $level"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop levels $level → 0 (cascade)"
    echo "  2. Rebuild all images"
    echo "  3. Force recreate all containers"
    echo ""
 
    # Step 1: Cascade stop (without removing volumes)
    if [ "$level" -gt 0 ]; then
        echo -e "${CYAN}Step 1: Stopping existing services (cascade)...${NC}"
        for current_level in $(seq $level -1 0); do
            print_level_header $current_level "Stopping"
            stop_level_only $current_level false
            echo -e "${GREEN}  ✓ Level $current_level stopped${NC}"
        done
        echo ""
    fi

    docker compose down -v

    # Step 2: Build all images for the level and dependencies
    echo -e "${CYAN}Step 2: Building images...${NC}"
    echo ""
    
    for build_level in $(seq 0 $level); do
        local services="${LEVEL_SERVICES[$build_level]}"
        local profile="${LEVEL_PROFILES[$build_level]}"
        
        echo -e "${MAGENTA}  Building Level $build_level: ${LEVEL_NAMES[$build_level]}${NC}"
        
        # Build with docker compose
        if [ -n "$profile" ]; then
            docker compose --profile "$profile" build $services 2>&1 | grep -E "Building|Successfully|FINISHED" || true
        else
            docker compose build $services 2>&1 | grep -E "Building|Successfully|FINISHED" || true
        fi
    done
    
    echo ""
    echo -e "${GREEN}  ✓ All images built${NC}"
    echo ""
    
    # Step 3: Start with force recreate (from 0 to level)
    echo -e "${CYAN}Step 3: Starting services with force recreate...${NC}"
    echo ""
    
    for start_level_num in $(seq 0 $level); do
        print_level_header $start_level_num "Force Recreating"
        
        local services="${LEVEL_SERVICES[$start_level_num]}"
        local profile="${LEVEL_PROFILES[$start_level_num]}"
        
        echo "  Force recreating services:"
        for service in $services; do
            echo -e "    • $service ${BLUE}[RECREATING]${NC}"
        done
        
        echo ""
        
        # Execute docker compose with build and force recreate
        if [ -n "$profile" ]; then
            docker compose --profile "$profile" up -d --build --force-recreate $services
        else
            docker compose up -d --build --force-recreate $services
        fi
        
        echo ""
        echo -e "${GREEN}  ✓ Level $start_level_num recreated${NC}"
    done
    
    echo ""
    echo -e "${GREEN}✓ Fresh start complete! All services rebuilt and recreated.${NC}"
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

check_level_4() {
    print_level_header 4
    
    # MLflow Server
    check "MLflow server running" \
        "check_service_running mlflow-server"
    
    if check_service_running mlflow-server; then
        check "MLflow server accessible" \
            "curl -sf http://localhost:5000/health"
        
        check "MLflow tracking API" \
            "curl -sf http://localhost:5000/api/2.0/mlflow/experiments/list" \
            true
        
        # Check MLflow artifacts bucket
        check_minio_bucket "mlflow-artifacts" "MLflow artifacts bucket exists"
        
        # Check experiment count
        EXPERIMENT_COUNT=$(curl -sf http://localhost:5000/api/2.0/mlflow/experiments/list 2>/dev/null | grep -o '"experiment_id"' | wc -l || echo "0")
        if [ "$EXPERIMENT_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} MLflow experiments: $EXPERIMENT_COUNT"
        else
            echo -e "    ${YELLOW}⚠${NC} No experiments yet (run training first)"
        fi
    fi
    
    # ML Training Prerequisites
    echo ""
    echo "  ML Training Prerequisites:"
    
    # Check offline features exist
    OFFLINE_FEATURES=$(docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | wc -l || echo "0")
    if [ "$OFFLINE_FEATURES" -gt 0 ]; then
        echo -e "    ${GREEN}✓${NC} Offline features: $OFFLINE_FEATURES files"
    else
        echo -e "    ${RED}✗${NC} No offline features (run Level 3 first)"
    fi
    
    # Check online features exist
    ONLINE_PATIENTS=$(docker exec redis redis-cli KEYS "patient:*:features" 2>/dev/null | wc -l || echo "0")
    if [ "$ONLINE_PATIENTS" -gt 0 ]; then
        echo -e "    ${GREEN}✓${NC} Online features: $ONLINE_PATIENTS patients"
    else
        echo -e "    ${YELLOW}⚠${NC} No online features (optional)"
    fi
    
    # Check ML training code exists
    if [ -f "./applications/ml-training/train.py" ]; then
        echo -e "    ${GREEN}✓${NC} ML training code exists"
    else
        echo -e "    ${RED}✗${NC} ML training code missing"
    fi
    
    if [ -f "./applications/ml-training/configs/model_config.yaml" ]; then
        echo -e "    ${GREEN}✓${NC} Training config exists"
    else
        echo -e "    ${YELLOW}⚠${NC} Training config missing"
    fi
    
    # ML Training readiness summary
    echo ""
    if [ "$OFFLINE_FEATURES" -gt 0 ] && check_service_running mlflow-server && [ -f "./applications/ml-training/train.py" ]; then
        echo -e "  ${GREEN}✓ Ready for ML training${NC}"
        echo -e "    Run: ${CYAN}./manage-pipeline.sh train${NC}"
    else
        echo -e "  ${YELLOW}⚠ Not ready for training${NC}"
        echo "    Prerequisites needed:"
        [ "$OFFLINE_FEATURES" -eq 0 ] && echo "      - Run feature engineering (Level 3)"
        ! check_service_running mlflow-server && echo "      - Start MLflow server"
        [ ! -f "./applications/ml-training/train.py" ] && echo "      - Add ML training code"
    fi
    
    echo ""
    
    # Model Serving (optional)
    check "Model serving running" \
        "check_service_running model-serving" \
        true
    
    if check_service_running model-serving; then
        check "Model serving health" \
            "curl -sf http://localhost:8000/health"
        
        check "Model serving API docs" \
            "curl -sf http://localhost:8000/docs" \
            true
    fi
    
    # ML Training service (run profile)
    check "ML training service available" \
        "test -f ./applications/ml-training/train.py"
}

check_ml_training_readiness() {
    print_header "ML Training Readiness Check"
    
    echo "  Validating full ML training pipeline..."
    echo ""
    
    local ALL_READY=true
    local MISSING_DEPS=()
    
    # Level 0: Infrastructure
    if ! check_service_running minio; then
        echo -e "  ${RED}✗${NC} MinIO not running (Level 0)"
        MISSING_DEPS+=("Start Level 0: ./manage-pipeline.sh start 0")
        ALL_READY=false
    else
        echo -e "  ${GREEN}✓${NC} MinIO running"
    fi
    
    if ! check_service_running redis; then
        echo -e "  ${RED}✗${NC} Redis not running (Level 0)"
        MISSING_DEPS+=("Start Level 0: ./manage-pipeline.sh start 0")
        ALL_READY=false
    else
        echo -e "  ${GREEN}✓${NC} Redis running"
    fi
    
    # Level 3: Features
    OFFLINE_FEATURES=$(docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | wc -l || echo "0")
    if [ "$OFFLINE_FEATURES" -eq 0 ]; then
        echo -e "  ${RED}✗${NC} No offline features (Level 3)"
        MISSING_DEPS+=("Run feature engineering: ./manage-pipeline.sh start 3")
        ALL_READY=false
    else
        echo -e "  ${GREEN}✓${NC} Offline features: $OFFLINE_FEATURES files"
    fi
    
    # Level 4: MLflow
    if ! check_service_running mlflow-server; then
        echo -e "  ${RED}✗${NC} MLflow server not running (Level 4)"
        MISSING_DEPS+=("Start Level 4: ./manage-pipeline.sh start 4")
        ALL_READY=false
    else
        if curl -sf http://localhost:5000/health > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} MLflow server running and healthy"
        else
            echo -e "  ${YELLOW}⚠${NC} MLflow server running but not accessible"
            MISSING_DEPS+=("Check MLflow logs: docker compose logs mlflow-server")
            ALL_READY=false
        fi
    fi
    
    # Training code
    if [ ! -f "./applications/ml-training/train.py" ]; then
        echo -e "  ${RED}✗${NC} Training code missing"
        MISSING_DEPS+=("Add ML training code to ./applications/ml-training/")
        ALL_READY=false
    else
        echo -e "  ${GREEN}✓${NC} Training code exists"
    fi
    
    if [ ! -f "./applications/ml-training/configs/model_config.yaml" ]; then
        echo -e "  ${YELLOW}⚠${NC} Training config missing"
        MISSING_DEPS+=("Add config: ./applications/ml-training/configs/model_config.yaml")
    else
        echo -e "  ${GREEN}✓${NC} Training config exists"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    
    if [ "$ALL_READY" = true ]; then
        echo -e "${GREEN}✓ ALL SYSTEMS GO - Ready for training!${NC}"
        echo ""
        echo "Next steps:"
        echo "  • Quick test:  ${CYAN}./manage-pipeline.sh test-train${NC}"
        echo "  • Full train:  ${CYAN}./manage-pipeline.sh train${NC}"
        echo "  • Visualize:   ${CYAN}./manage-pipeline.sh visualize${NC}"
        return 0
    else
        echo -e "${RED}✗ Prerequisites not met${NC}"
        echo ""
        echo "Required actions:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  • $dep"
        done
        return 1
    fi
}

# Add after the level functions (around line 450)

run_ml_training() {
    print_header "🎯 Running ML Training Pipeline"
    
    # Check if Level 4 is running
    if ! check_service_running mlflow-server; then
        echo -e "${RED}✗ MLflow server not running${NC}"
        echo "Start Level 4 first: ./manage-pipeline.sh start 4"
        exit 1
    fi
    
    # Check prerequisites
    echo "Checking prerequisites..."
    OFFLINE_FEATURES=$(docker exec minio mc ls myminio/clinical-mlops/features/offline/ --recursive 2>/dev/null | wc -l || echo "0")
    
    if [ "$OFFLINE_FEATURES" -eq 0 ]; then
        echo -e "${RED}✗ No features in offline store${NC}"
        echo "Run feature engineering first: ./manage-pipeline.sh start 3"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites met${NC}"
    echo ""
    
    # Run training
    echo "Starting training pipeline..."
    echo ""
    
    docker compose --profile ml-pipeline run --rm ml-training python train.py
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Training completed successfully${NC}"
        echo ""
        echo "View results:"
        echo "  MLflow UI: ${CYAN}http://localhost:5000${NC}"
        echo ""
        echo "Visualize training:"
        echo "  ${CYAN}./scripts/visualize-training.sh${NC}"
    else
        echo ""
        echo -e "${RED}✗ Training failed${NC}"
        echo ""
        echo "Check logs:"
        echo "  ${CYAN}docker compose logs ml-training${NC}"
        exit 1
    fi
}

# Update the help function to include new commands (around line 700)
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

LEVEL MANAGEMENT:
  start <N>              Start level N and its dependencies (0-$MAX_LEVEL)
  stop <N>               CASCADE STOP: Stop level N and all lower levels (N → 0)
  restart <N>            Restart specific level only
  status [N]             Show status of level N (or all if N not specified)
  logs <N> [service]     Show logs for level N services

FULL STACK:
  start-all              Start all levels (0-$MAX_LEVEL)
  stop-all               Stop all levels
  restart-all            Restart all levels
  
ADVANCED:
  rebuild <N>            Rebuild and restart level N
  fresh-start <N>        Stop, rebuild, and start level N (FULL CLEAN START)
  clean                  Remove all containers, volumes, networks (DESTRUCTIVE)

ML TRAINING:
  train                  Run full ML training pipeline
  test-train             Quick test training (single model)
  visualize              Visualize training results

UTILITIES:
  health [N]             Run health checks for level N (or all)
  clean-logs             Clean up old log files
  help                   Show this help message

LEVELS:
EOF
    for level in $(seq 0 $MAX_LEVEL); do
        echo "  $level: ${LEVEL_NAMES[$level]}"
    done
    echo ""
}

# Update main case statement (around line 730)
case "$1" in
    # ... existing cases ...
    
    train)
        run_ml_training
        ;;
    
    test-train)
        test_ml_training
        ;;
    
    visualize)
        ./scripts/visualize-training.sh
        ;;
    
    # ... rest of cases ...
esac

test_ml_training() {
    print_header "🧪 Testing ML Training Pipeline"
    
    echo "Running quick test with Logistic Regression only..."
    echo ""
    
    # Check prerequisites
    if ! check_service_running mlflow-server; then
        echo -e "${RED}✗ MLflow server not running${NC}"
        echo "Start Level 4 first: ./manage-pipeline.sh start 4"
        exit 1
    fi
    
    # Run test configuration
    docker compose --profile ml-pipeline run --rm \
        -e CONFIG_PATH=configs/test_config.yaml \
        ml-training python train.py
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Test completed successfully${NC}"
        echo ""
        echo "Check results: ${CYAN}http://localhost:5000${NC}"
    else
        echo ""
        echo -e "${RED}✗ Test failed${NC}"
        exit 1
    fi
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
    printf "${CYAN}Clinical MLOps Pipeline Manager${NC}\n\n"
    
    printf "${GREEN}Usage:${NC}\n"
    printf "  $0 [option]\n\n"
    
    printf "${GREEN}Options:${NC}\n"
    printf "  -s, --start-level <N>         Start level N and its dependencies\n"
    printf "  -S, --start-level-rebuild <N> Fresh start: stop cascade, rebuild, force recreate\n"
    printf "  -x, --stop-level <N>          Stop level N + cascade (N→0, keeps volumes)\n"
    printf "  -X, --stop-level-full <N>     Stop level N + cascade (N→0, removes volumes)\n"
    printf "  -r, --restart-level <N>       Restart level N only\n"
    printf "  -l, --logs <N>                Follow logs for level N\n\n"
    printf "  --start-full                  Start all levels (0-5)\n"
    printf "  --stop-full                   Stop all levels (removes containers, keeps volumes)\n\n"
    printf "  --status                      Show status of all levels\n\n"
    printf "  --clean-all                   Full cleanup (removes EVERYTHING including images)\n\n"
    printf "  -h, --help                    Show this help message\n\n"

    printf "${GREEN}Examples:${NC}\n"
    printf "  # Start infrastructure only\n"
    printf "  $0 --start-level 0\n\n"
    printf "  # Fresh start data ingestion (rebuild everything)\n"
    printf "  $0 --start-level-rebuild 1\n\n"
    printf "  # Start data ingestion (auto-starts level 0)\n"
    printf "  $0 --start-level 1\n\n"
    printf "  # Start ML Pipeline (auto-starts levels 0, 1, 2, 3)\n"
    printf "  $0 --start-level 4\n\n"
    printf "  # Fresh start ML Pipeline (rebuild all images from 0-4)\n"
    printf "  $0 --start-level-rebuild 4\n\n"
    printf "  # Stop data processing + cascade (stops 2, 1, 0)\n"
    printf "  $0 --stop-level 2\n\n"
    printf "  # Stop feature engineering + cascade with volumes (stops 3, 2, 1, 0)\n"
    printf "  $0 --stop-level-full 3\n\n"
    printf "  # Start everything\n"
    printf "  $0 --start-full\n\n"
    printf "  # Show status\n"
    printf "  $0 --status\n\n"
    printf "  # View logs for data processing\n"
    printf "  $0 --logs 2\n\n"
    printf "  # Full cleanup (removes everything)\n"
    printf "  $0 --clean-all\n\n"

    printf "${GREEN}Level Architecture:${NC}\n"
    printf "${CYAN}Level 0: Infrastructure${NC}\n"
    printf "  • minio, postgres (mlflow/airflow), redis, kafka, zookeeper\n"
    printf "  • ${YELLOW}Note: MLflow server moved to Level 4${NC}\n\n"
    
    printf "${CYAN}Level 1: Data Ingestion${NC}\n"
    printf "  • kafka-producer, kafka-consumer, clinical-mq, data-gateway\n"
    printf "  • Depends on: Level 0\n\n"
    
    printf "${CYAN}Level 2: Data Processing${NC}\n"
    printf "  • spark-master, spark-worker, spark-streaming, spark-batch\n"
    printf "  • Depends on: Levels 0, 1\n\n"
    
    printf "${CYAN}Level 3: Feature Engineering${NC}\n"
    printf "  • feature-engineering\n"
    printf "  • Depends on: Levels 0, 1, 2\n\n"
    
    printf "${CYAN}Level 4: ML Pipeline${NC}\n"
    printf "  • ${YELLOW}mlflow-server${NC}, ml-training, model-serving\n"
    printf "  • Depends on: Levels 0, 1, 2, 3\n\n"
    
    printf "${CYAN}Level 5: Observability${NC}\n"
    printf "  • airflow, prometheus, grafana, opensearch\n"
    printf "  • Depends on: Levels 0, 1, 2, 3, 4\n\n"

    printf "${YELLOW}Important Notes:${NC}\n"
    printf "  • ${GREEN}CASCADE STOP:${NC} --stop-level N stops N, N-1, ..., 0\n"
    printf "    Example: --stop-level 3 stops levels 3, 2, 1, 0\n\n"
    printf "  • ${GREEN}REBUILD:${NC} --start-level-rebuild N does:\n"
    printf "    1. Stop levels N → 0 (cascade)\n"
    printf "    2. Rebuild all images (0 → N)\n"
    printf "    3. Force recreate containers (0 → N)\n\n"
    printf "  • --stop-level removes containers but keeps volumes (for data persistence)\n"
    printf "  • --stop-level-full removes containers AND volumes (clean slate)\n"
    printf "  • --clean-all removes EVERYTHING including images (nuclear option)\n"
    printf "  • Starting a level automatically starts its dependencies\n"
    printf "  • ${YELLOW}MLflow server is now in Level 4 (ML Pipeline), not Level 0${NC}\n\n"

    printf "${CYAN}Cascade Stop Behavior:${NC}\n"
    printf "  --stop-level 5  →  Stops 5, 4, 3, 2, 1, 0\n"
    printf "  --stop-level 4  →  Stops 4, 3, 2, 1, 0\n"
    printf "  --stop-level 3  →  Stops 3, 2, 1, 0\n"
    printf "  --stop-level 2  →  Stops 2, 1, 0\n"
    printf "  --stop-level 1  →  Stops 1, 0\n"
    printf "  --stop-level 0  →  Stops 0 only\n\n"

    printf "${CYAN}Rebuild Behavior:${NC}\n"
    printf "  --start-level-rebuild 2  →  Stop (2→0), Rebuild (0→2), Start (0→2)\n\n"
    printf "${YELLOW}Use rebuild when:${NC}\n"
    printf "  • Code changes in applications\n"
    printf "  • Dockerfile modifications\n"
    printf "  • Need fresh containers\n"
    printf "  • Debugging issues\n"
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
        
    -S|--start-level-rebuild)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a level (0-$MAX_LEVEL)${NC}"
            exit 1
        fi
        
        level=$2
        
        if [ "$level" -lt 0 ] || [ "$level" -gt $MAX_LEVEL ]; then
            echo -e "${RED}Error: Invalid level. Must be 0-$MAX_LEVEL${NC}"
            exit 1
        fi
        
        start_level_rebuild $level
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