#!/bin/bash
#
# Pipeline Manager - Clinical MLOps Infrastructure Management
# Uses modular scripts for clean, maintainable operations
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_ENGINEERING_DIR="${SCRIPT_DIR}/scripts/feature-engineering"
ACTIVE_MAX_LEVEL=6

# Source common utilities
source "${SCRIPT_DIR}/scripts/common/config.sh"
source "${SCRIPT_DIR}/scripts/common/utils.sh"
source "${SCRIPT_DIR}/scripts/common/validation.sh"

# Source level management scripts
source "${SCRIPT_DIR}/scripts/infrastructure/manage.sh"
source "${SCRIPT_DIR}/scripts/infrastructure/health-checks.sh"
source "${SCRIPT_DIR}/scripts/data-ingestion/manage.sh"
source "${SCRIPT_DIR}/scripts/data-ingestion/health-checks.sh"
source "${SCRIPT_DIR}/scripts/processing-layer/manage.sh"
source "${SCRIPT_DIR}/scripts/processing-layer/health-checks.sh"
source "${SCRIPT_DIR}/scripts/feature-engineering/manage.sh"
source "${SCRIPT_DIR}/scripts/feature-engineering/health-checks.sh"
source "${SCRIPT_DIR}/scripts/ml-layer/manage.sh"
source "${SCRIPT_DIR}/scripts/ml-layer/health-checks.sh"
source "${SCRIPT_DIR}/scripts/orchestration/manage.sh"
source "${SCRIPT_DIR}/scripts/orchestration/health-checks.sh"
source "${SCRIPT_DIR}/scripts/observability/manage.sh"
source "${SCRIPT_DIR}/scripts/observability/metrics-setup.sh"
source "${SCRIPT_DIR}/scripts/observability/health-checks.sh"

# Source debug commands module
source "${SCRIPT_DIR}/scripts/debug-monitoring/debug-final.sh"

# --- Command Line Parsing ---

# Flags
ACTION=""
TARGET_LEVEL=0  # Default to Level 0
SHOW_HEALTH=false
SHOW_LOGS=false
SHOW_SUMMARY=false
SHOW_OPEN=false
SHOW_STATS=false
VISUALIZE=false
RUN_COMPARE_STORES=false
COMPARE_STORES_DATE=""
RUN_INSPECT_VOLUME=false
FEATURE_VOLUME_NAME=""
RUN_MONITOR_PIPELINE=false
MONITOR_PROCESS_DATE=""
RUN_QUERY_OFFLINE=false
QUERY_OFFLINE_DATE=""
RUN_QUERY_ONLINE=false
QUERY_ONLINE_PATIENT=""
RUN_TRAINING=false
DEBUG_LEVEL=-1  # Default to no debug

# Show usage
show_usage() {
    local usage
    usage=$(cat << EOF
${CYAN}Clinical MLOps Pipeline Manager${NC}

${GREEN}Usage:${NC}
  $0 [MANAGEMENT_COMMAND] --level <N> [OPTIONS]

${GREEN}Management Commands (Mutually Exclusive):${NC}
  --start               Start level services
  --stop                Stop services and remove volumes (data loss!)
  --restart-rebuild     Rebuild and restart services
  --clean               Full cleanup with cascading to dependencies (interactive confirmation)

${GREEN}Level Selection:${NC}
  --level <N>           Target level (0-${ACTIVE_MAX_LEVEL})
                         0 = Infrastructure
                         1 = Data Ingestion
                         2 = Data Processing
                         3 = Feature Engineering
                         4 = ML Pipeline
                         5 = Orchestration (Airflow)
                         6 = Observability/Monitoring

${YELLOW}Supported Levels:${NC} Management commands currently enabled for levels 0-5

${GREEN}Information Commands (Can be combined):${NC}
  -h, --health-check    Run health checks
  -l, --logs            Show logs
  -o, --open            Show service URLs
  -s, --summary         Show summary
  -d, --stats           Show data statistics (Level 1+)
  -v, --visualize       Show visualization
   --debug-level N       Run debug commands (0-6, cascading levels)

${GREEN}Feature Engineering Utilities (--level 3 only):${NC}
  --compare-stores [DATE]          Compare offline (MinIO) vs online (Redis) feature stores
  --inspect-feature-volume [NAME]  Inspect the feature store Docker volume
  --monitor-feature-pipeline [DATE]  Run end-to-end feature pipeline monitor
  --query-offline-features [DATE]  Explore offline feature Parquet data
  --query-online-features [PATIENT] Inspect a patient's online features from Redis

${GREEN}ML Pipeline Utilities (--level 4 only):${NC}
  --run-training                   Trigger an on-demand ML training job (Docker Compose run)

${GREEN}Level-Specific Commands:${NC}
  Level 0 - Infrastructure
    $0 --start --level 0             Start core infrastructure stack
    $0 -vh --level 0                 Visualize and run health checks
    $0 --stop --level 0              Stop infrastructure only
    $0 --debug-level 2 --level 0     Run resource monitoring debug

  Level 1 - Data Ingestion
    $0 --start -h --level 1          Start ingestion services with health checks
    $0 -sd --level 1                 Show status plus ingestion statistics
    $0 --restart-rebuild --level 1   Rebuild gateway, MQ, and processors
    $0 --debug-level 3 --level 1     Run network analysis debug

  Level 2 - Data Processing
    $0 --start --level 2             Launch Spark batch + streaming jobs (auto-starts 0-1)
    $0 -vhs --level 2                Visualize, run health checks, and summary
    $0 --stop --level 2              Cascade stop for processing + lower levels
    $0 --debug-level 4 --level 2     Run data flow analysis debug

  Level 3 - Feature Engineering
    $0 --start --level 3             Start feature engineering with dependencies
    $0 --compare-stores --level 3    Compare offline vs online feature stores
    $0 --monitor-feature-pipeline 2025-10-25 --level 3  Monitor pipeline for a specific date
    $0 --query-online-features PT00042 --level 3        Inspect online features for a patient
    $0 --debug-level 5 --level 3     Run performance deep dive debug

  Level 4 - ML Pipeline
    $0 --start --level 4             Start MLflow + model serving (auto-starts 0-3)
    $0 --run-training --level 4      Launch a one-off training job via docker compose run
    $0 --stop --level 4              Cascade stop for ML pipeline and dependencies
    $0 --debug-level 1 --level 4     Run service health debug

  Level 5 - Orchestration (Airflow)
    $0 --start --level 5             Start Airflow webserver + scheduler (auto-starts 0-4)
    $0 -vh --level 5                 Visualize and run health checks for Airflow
    $0 --stop --level 5              Cascade stop for Airflow and dependencies
    $0 --debug-level 0 --level 5     Run basic system status debug

${YELLOW}Command Rules:${NC}
  • Only ONE management command per execution
  • Information commands can be combined with management commands (except --clean)
  • Example: --start -vhs ✓  |  --start --stop ✗
  • Note: --clean skips information commands (cleanup is final operation)

${CYAN}Available Levels:${NC}
  Level 0: MinIO, PostgreSQL, Redis, Kafka, Zookeeper
  Level 1: Kafka Producer/Consumer, Clinical Gateway, Lab Processor
  Level 2: Spark Master/Workers, Streaming, Batch Processing
  Level 3: Feature Engineering (Offline + Online stores)
  Level 4: MLflow, ML Training, Model Serving
  Level 5: Airflow
  Level 6: Prometheus, Grafana, OpenSearch
  Level 7: ArgoCD, Github Actions, Istio Mesh, Kubernetes, Argo rollouts, DAST, SAST (blue and green deployments)
  LEVEL 8: Penetration testing - metasploit and other tools... we leave in vulnerabilities to help us testing

${YELLOW}Note:${NC} Starting a level automatically starts its dependencies

EOF
)
    printf "%b" "$usage"
}

# Parse arguments
parse_arguments() {
    local has_start=false
    local has_stop=false
    local has_restart=false
    local has_clean=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --start)
                has_start=true
                ACTION="start"
                shift
                ;;
            --stop)
                has_stop=true
                ACTION="stop"
                shift
                ;;
            --restart-rebuild)
                has_restart=true
                ACTION="restart"
                shift
                ;;
            --clean)
                has_clean=true
                ACTION="clean"
                shift
                ;;
            -h|--health-check)
                SHOW_HEALTH=true
                shift
                ;;
            -l|--logs)
                SHOW_LOGS=true
                shift
                ;;
            -o|--open)
                SHOW_OPEN=true
                shift
                ;;
            -s|--summary)
                SHOW_SUMMARY=true
                shift
                ;;
            -v|--visualize)
                VISUALIZE=true
                shift
                ;;
            --compare-stores=*)
                RUN_COMPARE_STORES=true
                COMPARE_STORES_DATE="${1#*=}"
                shift
                ;;
            --compare-stores)
                RUN_COMPARE_STORES=true
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    COMPARE_STORES_DATE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --inspect-feature-volume=*)
                RUN_INSPECT_VOLUME=true
                FEATURE_VOLUME_NAME="${1#*=}"
                shift
                ;;
            --inspect-feature-volume)
                RUN_INSPECT_VOLUME=true
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    FEATURE_VOLUME_NAME="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --monitor-feature-pipeline=*)
                RUN_MONITOR_PIPELINE=true
                MONITOR_PROCESS_DATE="${1#*=}"
                shift
                ;;
            --monitor-feature-pipeline)
                RUN_MONITOR_PIPELINE=true
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    MONITOR_PROCESS_DATE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --query-offline-features=*)
                RUN_QUERY_OFFLINE=true
                QUERY_OFFLINE_DATE="${1#*=}"
                shift
                ;;
            --query-offline-features)
                RUN_QUERY_OFFLINE=true
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    QUERY_OFFLINE_DATE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --query-online-features=*)
                RUN_QUERY_ONLINE=true
                QUERY_ONLINE_PATIENT="${1#*=}"
                shift
                ;;
            --query-online-features)
                RUN_QUERY_ONLINE=true
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    QUERY_ONLINE_PATIENT="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --run-training)
                RUN_TRAINING=true
                shift
                ;;
            --debug-level)
                if [ -z "$2" ]; then
                    log_error "Please specify a debug level (0-5)"
                    exit 1
                fi
                DEBUG_LEVEL=$2
                if ! [[ "$DEBUG_LEVEL" =~ ^[0-6]$ ]]; then
                    log_error "Invalid debug level. Must be 0-6"
                    exit 1
                fi
                shift 2
                ;;
            --level)
                if [ -z "$2" ]; then
                    log_error "Please specify a level (0-${ACTIVE_MAX_LEVEL})"
                    exit 1
                fi
                TARGET_LEVEL=$2
                if ! [[ "$TARGET_LEVEL" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid level. Must be a number between 0 and ${ACTIVE_MAX_LEVEL}"
                    exit 1
                fi
                if [ "$TARGET_LEVEL" -lt 0 ] || [ "$TARGET_LEVEL" -gt "$ACTIVE_MAX_LEVEL" ]; then
                    log_error "Invalid level. Must be 0-${ACTIVE_MAX_LEVEL} (currently supporting Levels 0-${ACTIVE_MAX_LEVEL})"
                    exit 1
                fi
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                # Handle combined short flags (e.g., -vso, -hls)
                local flags="${1#-}"
                for ((i=0; i<${#flags}; i++)); do
                    case "${flags:$i:1}" in
                        h) SHOW_HEALTH=true ;;
                        l) SHOW_LOGS=true ;;
                        o) SHOW_OPEN=true ;;
                        s) SHOW_SUMMARY=true ;;
                        v) VISUALIZE=true ;;
                        *)
                            log_error "Unknown flag: -${flags:$i:1}"
                            exit 1
                            ;;
                    esac
                done
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate mutual exclusivity
    if ! validate_management_commands "$has_start" "$has_stop" "$has_restart" "$has_clean"; then
        show_conflict_error
        exit 1
    fi

    # Disable all information commands when cleaning
    if [ "$has_clean" = true ]; then
        SHOW_HEALTH=false
        SHOW_LOGS=false
        SHOW_SUMMARY=false
        SHOW_OPEN=false
        VISUALIZE=false
    fi

    if [ "$TARGET_LEVEL" -ne 3 ]; then
        if [ "$RUN_COMPARE_STORES" = true ] || [ "$RUN_INSPECT_VOLUME" = true ] || \
           [ "$RUN_MONITOR_PIPELINE" = true ] || [ "$RUN_QUERY_OFFLINE" = true ] || \
           [ "$RUN_QUERY_ONLINE" = true ]; then
            log_error "Feature engineering utilities require --level 3"
            exit 1
        fi
    fi

    if [ "$RUN_TRAINING" = true ] && [ "$TARGET_LEVEL" -ne 4 ]; then
        log_error "ML pipeline training utility requires --level 4"
        exit 1
    fi
}

# --- Level Utilities ---

resolve_level_hierarchy() {
    local target="$1"
    declare -A visited=()
    local -a queue=("$target")
    local -a collected=()

    while [ "${#queue[@]}" -gt 0 ]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")

        if [[ -z "$current" ]]; then
            continue
        fi

        if [[ -n "${visited[$current]}" ]]; then
            continue
        fi

        visited[$current]=1
        collected+=("$current")

        local deps="${LEVEL_DEPENDENCIES[$current]:-}"
        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                queue+=("$dep")
            done
        fi
    done

    if [ "${#collected[@]}" -eq 0 ]; then
        collected+=("$target")
    fi

    printf "%s\n" "${collected[@]}" | sort -n | uniq
}

run_summary_for_level() {
    local level="$1"
    case $level in
        0) show_infrastructure_status ;;
        1) show_data_ingestion_status ;;
        2) show_data_processing_status ;;
        3) show_feature_engineering_status ;;
        4) show_ml_pipeline_status ;;
        5) show_orchestration_status ;;
        *)
            log_warning "Summary not implemented for level $level yet"
            ;;
    esac
}

run_health_checks_for_level() {
    local level="$1"
    case $level in
        0) run_infrastructure_health_checks ;;
        1) run_data_ingestion_health_checks ;;
        2) run_data_processing_health_checks ;;
        3) run_feature_engineering_health_checks ;;
        4) run_ml_pipeline_health_checks ;;
        5) run_orchestration_health_checks ;;
        *)
            log_warning "Health checks not implemented for level $level yet"
            ;;
    esac
}

run_visualization_for_level() {
    local level="$1"
    case $level in
        0)
            log_info "Infrastructure Visualization"
            quick_infrastructure_status
            echo ""
            check_data_accessibility
            ;;
        1)
            log_info "Data Ingestion Visualization"
            quick_data_ingestion_status
            echo ""
            check_kafka_data_flow
            ;;
        2)
            log_info "Data Processing Visualization"
            quick_data_processing_status
            echo ""
            inspect_spark_outputs
            ;;
        3)
            log_info "Feature Engineering Visualization"
            quick_feature_engineering_status
            echo ""
            inspect_feature_store_outputs
            ;;
        4)
            log_info "ML Pipeline Visualization"
            quick_ml_pipeline_status
            echo ""
            inspect_ml_pipeline_outputs
            ;;
         5)
            log_info "Orchestration Visualization"
            quick_orchestration_status
            echo ""
            show_orchestration_urls
            ;;
         6)
            log_info "Observability Visualization"
            quick_observability_status
            echo ""
            show_observability_urls
            ;;
        *)
            log_warning "Visualization not implemented for level $level yet"
            ;;
    esac
}

run_service_urls_for_level() {
    local level="$1"
    case $level in
        0) show_service_urls ;;
        1) show_data_ingestion_urls ;;
        2) show_data_processing_urls ;;
        3) show_feature_engineering_urls ;;
        4) show_ml_pipeline_urls ;;
        5) show_orchestration_urls ;;
        *)
            log_warning "Service URLs not available for level $level yet"
            ;;
    esac
}

# --- Main Execution ---

main() {
    local exit_status=0
    # Parse command line
    parse_arguments "$@"
    
    # Run pre-flight checks
    if ! run_preflight_checks; then
        exit 1
    fi
    
    # Default to summary if no action or info command
    if [ -z "$ACTION" ] && [ "$SHOW_HEALTH" = false ] && [ "$SHOW_LOGS" = false ] && [ "$SHOW_SUMMARY" = false ] && [ "$SHOW_OPEN" = false ] && [ "$VISUALIZE" = false ] && [ "$DEBUG_LEVEL" -eq -1 ]; then
        SHOW_SUMMARY=true
    fi
    
    # Execute management command based on level
    case $ACTION in
        start)
            # Get all levels to start (dependencies first, then target)
            mapfile -t start_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
            
            log_info "Starting levels: ${start_levels[*]}"
            echo ""
            
            # Start each level in order (dependencies first, then target)
            for level in "${start_levels[@]}"; do
                log_info "Starting Level $level: ${LEVEL_NAMES[$level]}..."
                case $level in
                    0)
                        start_infrastructure false
                        ;;
                    1)
                        start_data_ingestion false
                        ;;
                    2)
                        start_data_processing false
                        ;;
                    3)
                        start_feature_engineering false
                        ;;
                    4)
                        start_ml_pipeline false
                        ;;
                     5)
                        start_orchestration false
                        ;;
                     6)
                        start_observability false
                        ;;
                esac
            done
            ;;
        stop)
            # Get all levels to stop (target level + dependencies for cascading levels)
            local stop_levels=()
            if [ "$TARGET_LEVEL" -eq 0 ] || [ "$TARGET_LEVEL" -eq 1 ] || [ "$TARGET_LEVEL" -eq 3 ] || [ "$TARGET_LEVEL" -eq 6 ]; then
                # Levels 0, 1, 3, 6: stop only the target level (no cascading)
                stop_levels=("$TARGET_LEVEL")
            else
                # Levels 2, 4, 5: cascade stop to dependencies
                mapfile -t stop_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
            fi
            
            log_info "Stopping levels: ${stop_levels[*]}"
            echo ""
            
            # Stop each level in order (dependencies first, then target)
            for level in "${stop_levels[@]}"; do
                log_info "Stopping Level $level: ${LEVEL_NAMES[$level]}..."
                case $level in
                    0)
                        stop_infrastructure true false  # Remove containers AND volumes, no cascade
                        ;;
                    1)
                        stop_data_ingestion true false  # Remove containers AND volumes, no cascade
                        ;;
                    2)
                        stop_data_processing true false  # Remove containers AND volumes, no cascade
                        ;;
                    3)
                        stop_feature_engineering true false  # Remove containers AND volumes, no cascade
                        ;;
                    4)
                        stop_ml_pipeline true false  # Remove containers AND volumes, no cascade
                        ;;
                     5)
                        stop_orchestration true false  # Remove containers AND volumes, no cascade
                        ;;
                     6)
                        stop_observability true false  # Remove containers AND volumes, no cascade
                        ;;
                esac
            done
            ;;
        restart)
            case $TARGET_LEVEL in
                0)
                    rebuild_infrastructure
                    ;;
                1)
                    rebuild_data_ingestion
                    ;;
                2)
                    rebuild_data_processing
                    ;;
                3)
                    rebuild_feature_engineering
                    ;;
                4)
                    rebuild_ml_pipeline
                    ;;
                 5)
                    rebuild_orchestration
                    ;;
                 6)
                    rebuild_observability
                    ;;
            esac
            ;;
        clean)
            print_header "🧹 Full Cleanup - Level $TARGET_LEVEL"
            
            # Get all levels to clean (target level + dependencies)
            local clean_levels=()
            mapfile -t clean_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
            
            echo -e "${RED}⚠️  DESTRUCTIVE OPERATION - This will permanently delete:${NC}"
            echo ""
            echo -e "${YELLOW}For Level $TARGET_LEVEL and all dependencies (${clean_levels[*]}):${NC}"
            echo "  • All running and stopped containers"
            echo "  • All named volumes (data will be lost)"
            echo "  • All custom networks"
            echo "  • All project-specific Docker images"
            echo "  • All dangling images"
            echo ""
            echo -e "${RED}This action cannot be undone!${NC}"
            echo ""
            read -p "Type 'yes' to confirm complete cleanup: " confirm
                if [ "$confirm" = "yes" ]; then
                    # Reverse the levels for cleanup (from highest to lowest)
                    reversed_levels=()
                    for ((i=${#clean_levels[@]}-1; i>=0; i--)); do
                        reversed_levels+=("${clean_levels[i]}")
                    done
                    log_info "Performing comprehensive cleanup for levels: ${reversed_levels[*]}"
                    echo ""

                    # Clean each level in reverse order (from highest to lowest)
                    for level in "${reversed_levels[@]}"; do
                        echo ""
                        echo "🧹 Cleaning Level $level..."
                        
                        # Step 1: Stop containers for this level
                        echo "  🛑 Stopping containers..."
                        docker compose stop --level $level 2>/dev/null || true
                        
                        # Step 2: Remove containers for this level
                        echo "  🗑️  Removing containers..."
                        docker compose rm -f --level $level 2>/dev/null || true
                        
                        # Step 3: Remove volumes for this level
                        echo "  💾 Removing volumes..."
                        docker compose down -v --level $level 2>/dev/null || true
                        
                        # Step 4: Remove networks for this level
                        echo "  🌐 Removing networks..."
                        docker compose down --remove-orphans --level $level 2>/dev/null || true
                    done
                    
                    # Final cleanup of any remaining resources
                    echo ""
                    echo "🧹 Final cleanup of remaining resources..."
                    
                    # Remove any remaining project containers
                    remaining_containers=$(docker ps -aq --filter "label=com.docker.compose.project=clinical-trials" 2>/dev/null || true)
                    if [ -n "$remaining_containers" ]; then
                        echo "  🗑️  Removing remaining containers..."
                        docker rm -f $remaining_containers 2>/dev/null || true
                    fi
                    
                    # Remove any remaining project volumes
                    remaining_volumes=$(docker volume ls -q --filter "label=com.docker.compose.project=clinical-trials" 2>/dev/null || true)
                    if [ -n "$remaining_volumes" ]; then
                        echo "  💾 Removing remaining volumes..."
                        docker volume rm -f $remaining_volumes 2>/dev/null || true
                    fi
                    
                    # Remove any remaining project networks
                    remaining_networks=$(docker network ls -q --filter "label=com.docker.compose.project=clinical-trials" 2>/dev/null || true)
                    if [ -n "$remaining_networks" ]; then
                        echo "  🌐 Removing remaining networks..."
                        docker network rm $remaining_networks 2>/dev/null || true
                    fi
                    
                    # Remove project-specific images
                    echo "  📦 Removing project-specific images..."
                    project_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "clinical-trials" 2>/dev/null || true)
                    if [ -n "$project_images" ]; then
                        echo "$project_images" | xargs -r docker rmi -f 2>/dev/null || true
                    fi
                    
                    # Remove dangling images
                    echo "  🧹 Removing dangling images..."
                    dangling_images=$(docker images -f "dangling=true" -q 2>/dev/null || true)
                    if [ -n "$dangling_images" ]; then
                        docker rmi -f $dangling_images 2>/dev/null || true
                    fi

                    echo ""
                    echo "✅ Cleanup completed!"
            else
                log_warning "Cleanup cancelled"
            fi
            ;;
    esac
    
    # Execute information commands based on level (skip after clean operations)
    if [ "$ACTION" != "clean" ]; then
        if [ "$SHOW_SUMMARY" = true ]; then
        echo ""
        local summary_levels=()
        mapfile -t summary_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
        local last_index=$((${#summary_levels[@]}-1))
        for idx in "${!summary_levels[@]}"; do
            run_summary_for_level "${summary_levels[$idx]}"
            if [ "$idx" -lt "$last_index" ]; then
                echo ""
            fi
        done
        fi

        if [ "$SHOW_HEALTH" = true ]; then
        echo ""
        local health_levels=()
        mapfile -t health_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
        local health_last=$((${#health_levels[@]}-1))
        local health_result=0
        for idx in "${!health_levels[@]}"; do
            if ! run_health_checks_for_level "${health_levels[$idx]}"; then
                health_result=1
            fi
            if [ "$idx" -lt "$health_last" ]; then
                echo ""
            fi
        done
        if [ "$health_result" -ne 0 ]; then
            exit_status=1
        fi
        fi

        if [ "$VISUALIZE" = true ]; then
        echo ""
        local visualization_levels=()
        mapfile -t visualization_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
        local viz_last=$((${#visualization_levels[@]}-1))
        for idx in "${!visualization_levels[@]}"; do
            run_visualization_for_level "${visualization_levels[$idx]}"
            if [ "$idx" -lt "$viz_last" ]; then
                echo ""
            fi
        done
        fi

        if [ "$SHOW_OPEN" = true ]; then
        echo ""
        local url_levels=()
        mapfile -t url_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
        local url_last=$((${#url_levels[@]}-1))
        for idx in "${!url_levels[@]}"; do
            run_service_urls_for_level "${url_levels[$idx]}"
            if [ "$idx" -lt "$url_last" ]; then
                echo ""
            fi
        done
        fi

        if [ "$TARGET_LEVEL" -eq 3 ]; then
        if [ "$RUN_COMPARE_STORES" = true ]; then
            echo ""
            log_info "Comparing feature stores..."
            if [ -n "$COMPARE_STORES_DATE" ]; then
                "${FEATURE_ENGINEERING_DIR}/compare_stores.sh" "$COMPARE_STORES_DATE"
            else
                "${FEATURE_ENGINEERING_DIR}/compare_stores.sh"
            fi
        fi

        if [ "$RUN_INSPECT_VOLUME" = true ]; then
            echo ""
            log_info "Inspecting feature store volume..."
            if [ -n "$FEATURE_VOLUME_NAME" ]; then
                "${FEATURE_ENGINEERING_DIR}/inspect_volume.sh" "$FEATURE_VOLUME_NAME"
            else
                "${FEATURE_ENGINEERING_DIR}/inspect_volume.sh"
            fi
        fi

        if [ "$RUN_MONITOR_PIPELINE" = true ]; then
            echo ""
            log_info "Running feature engineering pipeline monitor..."
            if [ -n "$MONITOR_PROCESS_DATE" ]; then
                "${FEATURE_ENGINEERING_DIR}/monitoring.sh" "$MONITOR_PROCESS_DATE"
            else
                "${FEATURE_ENGINEERING_DIR}/monitoring.sh"
            fi
        fi

        if [ "$RUN_QUERY_OFFLINE" = true ]; then
            echo ""
            log_info "Querying offline feature store..."
            if [ -n "$QUERY_OFFLINE_DATE" ]; then
                python3 "${FEATURE_ENGINEERING_DIR}/query_features.sh" offline "$QUERY_OFFLINE_DATE"
            else
                python3 "${FEATURE_ENGINEERING_DIR}/query_features.sh" offline
            fi
        fi

        if [ "$RUN_QUERY_ONLINE" = true ]; then
            echo ""
            log_info "Querying online feature store..."
            if [ -n "$QUERY_ONLINE_PATIENT" ]; then
                python3 "${FEATURE_ENGINEERING_DIR}/query_features.sh" online "$QUERY_ONLINE_PATIENT"
            else
                python3 "${FEATURE_ENGINEERING_DIR}/query_features.sh" online
            fi
        fi
        fi

        if [ "$RUN_TRAINING" = true ]; then
        echo ""
        run_ml_training_job
        fi

        if [ "$SHOW_LOGS" = true ]; then
        echo ""
        local log_levels=()
        mapfile -t log_levels < <(resolve_level_hierarchy "$TARGET_LEVEL")
        local services=()
        for level in "${log_levels[@]}"; do
            if [ -n "${LEVEL_SERVICES[$level]:-}" ]; then
                services+=(${LEVEL_SERVICES[$level]})
            fi
        done

        if [ "${#services[@]}" -eq 0 ]; then
            log_warning "No services available for level(s): ${log_levels[*]}"
        else
            log_info "Following logs for Levels ${log_levels[*]}..."
            docker compose logs -f "${services[@]}"
        fi
        fi

        # Execute debug commands
        if [ "$DEBUG_LEVEL" -ne -1 ]; then
            echo ""
            log_info "Running debug commands (Level $DEBUG_LEVEL)..."
            run_debug_commands "$DEBUG_LEVEL"
        fi
    fi

    # Show next steps
    if [ -n "$ACTION" ]; then
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "  • Check status:  $0 -s --level $TARGET_LEVEL"
        echo "  • Health check:  $0 -h --level $TARGET_LEVEL"
        echo "  • View logs:     $0 -l --level $TARGET_LEVEL"
        echo "  • Visualize:     $0 -v --level $TARGET_LEVEL"
        echo "  • Debug:         $0 --debug-level 2 --level $TARGET_LEVEL"
        echo ""
    fi

    return "$exit_status"
}

# Run main
main "$@"
