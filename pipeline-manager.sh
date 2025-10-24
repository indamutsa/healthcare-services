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

# Source infrastructure management
source "${SCRIPT_DIR}/scripts/infrastructure/manage.sh"

# --- Command Line Parsing ---

# Flags
ACTION=""
SHOW_HEALTH=false
SHOW_LOGS=false
SHOW_SUMMARY=false
VISUALIZE=false

# Show usage
show_usage() {
    cat << EOF
${CYAN}Clinical MLOps Pipeline Manager${NC}

${GREEN}Usage:${NC}
  $0 [MANAGEMENT_COMMAND] [OPTIONS]

${GREEN}Management Commands (Mutually Exclusive):${NC}
  --start               Start infrastructure services
  --stop                Stop infrastructure services
  --restart-rebuild     Rebuild and restart services
  --clean               Clean all resources (removes volumes)

${GREEN}Information Commands (Can be combined):${NC}
  -h, --health-check    Run health checks
  -l, --logs            Show logs
  -s, --summary         Show summary
  -v, --visualize       Show visualization

${GREEN}Examples:${NC}
  # Start infrastructure
  $0 --start

  # Start and run health checks
  $0 --start -h

  # Start with health checks and summary
  $0 --start -hs

  # Show status only
  $0 -s

  # Rebuild infrastructure
  $0 --restart-rebuild

  # Stop infrastructure
  $0 --stop

  # Clean everything
  $0 --clean

${YELLOW}Command Rules:${NC}
  • Only ONE management command per execution
  • Information commands can be freely combined
  • Example: --start -vhs ✓  |  --start --stop ✗

${CYAN}Infrastructure Services:${NC}
  • MinIO (object storage)
  • PostgreSQL (MLflow & Airflow databases)
  • Redis (feature store)
  • Kafka (message broker)
  • Zookeeper (Kafka coordination)

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
            -s|--summary)
                SHOW_SUMMARY=true
                shift
                ;;
            -v|--visualize)
                VISUALIZE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
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
    if [ -z "$ACTION" ] && [ "$SHOW_HEALTH" = false ] && [ "$SHOW_LOGS" = false ] && [ "$SHOW_SUMMARY" = false ] && [ "$VISUALIZE" = false ]; then
        SHOW_SUMMARY=true
    fi
    
    # Execute management command
    case $ACTION in
        start)
            start_infrastructure false
            ;;
        stop)
            stop_infrastructure false
            ;;
        restart)
            rebuild_infrastructure
            ;;
        clean)
            print_header "🧹 Cleaning Infrastructure"
            log_warning "This will remove all containers and volumes!"
            stop_infrastructure true
            log_success "Infrastructure cleaned"
            ;;
    esac
    
    # Execute information commands
    if [ "$SHOW_SUMMARY" = true ]; then
        echo ""
        show_infrastructure_status
    fi
    
    if [ "$SHOW_HEALTH" = true ]; then
        echo ""
        run_infrastructure_health_checks
    fi
    
    if [ "$VISUALIZE" = true ]; then
        echo ""
        log_info "Infrastructure Visualization"
        quick_infrastructure_status
        echo ""
        check_data_accessibility
    fi
    
    if [ "$SHOW_LOGS" = true ]; then
        echo ""
        log_info "Following logs for infrastructure services..."
        docker compose logs -f ${LEVEL_SERVICES[0]}
    fi
    
    # Show next steps
    if [ -n "$ACTION" ]; then
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "  • Check status:  $0 -s"
        echo "  • Health check:  $0 -h"
        echo "  • View logs:     $0 -l"
        echo "  • Visualize:     $0 -v"
        echo ""
    fi
}

# Run main
main "$@"