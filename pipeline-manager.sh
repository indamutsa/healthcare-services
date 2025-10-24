#!/bin/bash
#
# Pipeline Manager - Clinical MLOps Infrastructure Management
# Uses modular scripts for clean, maintainable operations
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Show usage
show_usage() {
    cat << EOF
${CYAN}Clinical MLOps Pipeline Manager${NC}

${GREEN}Usage:${NC}
  $0 [MANAGEMENT_COMMAND] --level <N> [OPTIONS]

${GREEN}Management Commands (Mutually Exclusive):${NC}
  --start               Start level services
  --stop                Stop services and remove volumes (data loss!)
  --restart-rebuild     Rebuild and restart services
  --clean               Full cleanup (interactive confirmation)

${GREEN}Level Selection:${NC}
  --level <N>           Target level (0-5)
                        0 = Infrastructure
                        1 = Data Ingestion
                        2 = Data Processing
                        3 = Feature Engineering
                        4 = ML Pipeline
                        5 = Observability

${YELLOW}Supported Levels:${NC} Management commands currently enabled for levels 0-2

${GREEN}Information Commands (Can be combined):${NC}
  -h, --health-check    Run health checks
  -l, --logs            Show logs
  -o, --open            Show service URLs
  -s, --summary         Show summary
  -d, --stats           Show data statistics (Level 1+)
  -v, --visualize       Show visualization

${GREEN}Examples:${NC}
  # Start infrastructure (Level 0)
  $0 --start --level 0

  # Start data ingestion with health checks (Level 1)
  $0 --start --level 1 -h

  # Show Level 1 status and statistics
  $0 -sd --level 1

  # Stop Level 1 services
  $0 --stop --level 1

  # Rebuild Level 0
  $0 --restart-rebuild --level 0

${YELLOW}Command Rules:${NC}
  • Only ONE management command per execution
  • Information commands can be freely combined
  • Example: --start -vhs ✓  |  --start --stop ✗

${CYAN}Available Levels:${NC}
  Level 0: MinIO, PostgreSQL, Redis, Kafka, Zookeeper
  Level 1: Kafka Producer/Consumer, Clinical Gateway, Lab Processor
  Level 2: Spark Master/Workers, Streaming, Batch Processing
  Level 3: Feature Engineering (Offline + Online stores)
  Level 4: MLflow, ML Training, Model Serving
  Level 5: Airflow, Prometheus, Grafana, OpenSearch

${YELLOW}Note:${NC} Starting a level automatically starts its dependencies

EOF
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
            --level)
                if [ -z "$2" ]; then
                    log_error "Please specify a level (0-2)"
                    exit 1
                fi
                TARGET_LEVEL=$2
                if [ "$TARGET_LEVEL" -lt 0 ] || [ "$TARGET_LEVEL" -gt 2 ]; then
                    log_error "Invalid level. Must be 0-2 (currently supporting Level 0, 1, and 2)"
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
}

# --- Main Execution ---

main() {
    # Parse command line
    parse_arguments "$@"
    
    # Run pre-flight checks
    if ! run_preflight_checks; then
        exit 1
    fi
    
    # Default to summary if no action or info command
    if [ -z "$ACTION" ] && [ "$SHOW_HEALTH" = false ] && [ "$SHOW_LOGS" = false ] && [ "$SHOW_SUMMARY" = false ] && [ "$SHOW_OPEN" = false ] && [ "$VISUALIZE" = false ]; then
        SHOW_SUMMARY=true
    fi
    
    # Execute management command based on level
    case $ACTION in
        start)
            case $TARGET_LEVEL in
                0)
                    start_infrastructure false
                    ;;
                1)
                    start_data_ingestion false
                    ;;
                2)
                    start_data_processing false
                    ;;
            esac
            ;;
        stop)
            case $TARGET_LEVEL in
                0)
                    stop_infrastructure true  # Remove containers AND volumes
                    ;;
                1)
                    stop_data_ingestion true  # Remove containers AND volumes
                    ;;
                2)
                    stop_data_processing true  # Remove containers AND volumes
                    ;;
            esac
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
            esac
            ;;
        clean)
            print_header "🧹 Full Cleanup - Level $TARGET_LEVEL"
            echo -e "${RED}This will remove all containers, volumes, and networks!${NC}"
            echo ""
            read -p "Are you sure? Type 'yes' to continue: " confirm
            if [ "$confirm" = "yes" ]; then
                case $TARGET_LEVEL in
                    0)
                        stop_infrastructure true
                        ;;
                    1)
                        stop_data_ingestion true
                        ;;
                    2)
                        stop_data_processing true
                        ;;
                esac
                docker compose down -v --remove-orphans 2>/dev/null || true
                log_success "Level $TARGET_LEVEL fully cleaned"
            else
                log_warning "Cleanup cancelled"
            fi
            ;;
    esac
    
    # Execute information commands based on level
    if [ "$SHOW_SUMMARY" = true ]; then
        echo ""
        case $TARGET_LEVEL in
            0)
                show_infrastructure_status
                ;;
            1)
                show_data_ingestion_status
                ;;
            2)
                show_data_processing_status
                ;;
        esac
    fi

    if [ "$SHOW_HEALTH" = true ]; then
        echo ""
        case $TARGET_LEVEL in
            0)
                run_infrastructure_health_checks
                ;;
            1)
                run_data_ingestion_health_checks
                ;;
            2)
                run_data_processing_health_checks
                ;;
        esac
    fi

    if [ "$VISUALIZE" = true ]; then
        echo ""
        case $TARGET_LEVEL in
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
        esac
    fi

    if [ "$SHOW_OPEN" = true ]; then
        echo ""
        case $TARGET_LEVEL in
            0)
                show_service_urls
                ;;
            1)
                show_data_ingestion_urls
                ;;
            2)
                show_data_processing_urls
                ;;
        esac
    fi

    if [ "$SHOW_LOGS" = true ]; then
        echo ""
        local level_services="${LEVEL_SERVICES[$TARGET_LEVEL]}"
        log_info "Following logs for Level $TARGET_LEVEL services..."
        docker compose logs -f $level_services
    fi

    # Show next steps
    if [ -n "$ACTION" ]; then
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "  • Check status:  $0 -s --level $TARGET_LEVEL"
        echo "  • Health check:  $0 -h --level $TARGET_LEVEL"
        echo "  • View logs:     $0 -l --level $TARGET_LEVEL"
        echo "  • Visualize:     $0 -v --level $TARGET_LEVEL"
        echo ""
    fi
}

# Run main
main "$@"
