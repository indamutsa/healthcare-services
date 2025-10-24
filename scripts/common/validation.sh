#!/bin/bash
#
# Input Validation and Error Handling
# Validates user input and provides clear error messages
#

# Source configuration and utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

# --- Command Validation ---

# Validate level argument
validate_level() {
    local level=$1
    
    if [ -z "$level" ]; then
        log_error "Please specify a level (0-$MAX_LEVEL)"
        return 1
    fi
    
    if ! is_valid_level "$level"; then
        log_error "Invalid level: $level. Must be between 0 and $MAX_LEVEL"
        return 1
    fi
    
    return 0
}

# Validate that only one management command is provided
validate_management_commands() {
    local start=$1
    local stop=$2
    local restart=$3
    local clean=$4
    local count=0
    
    [ "$start" = true ] && count=$((count + 1))
    [ "$stop" = true ] && count=$((count + 1))
    [ "$restart" = true ] && count=$((count + 1))
    [ "$clean" = true ] && count=$((count + 1))
    
    if [ $count -gt 1 ]; then
        log_error "Management commands are mutually exclusive"
        log_error "Cannot use --start, --stop, --restart-rebuild, --clean together"
        echo -e "${GREEN}✅ Use only ONE management command per execution${NC}"
        return 1
    fi
    
    return 0
}

# --- Docker Validation ---

# Check if Docker is running
check_docker_running() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running"
        echo "Please start Docker and try again"
        return 1
    fi
    return 0
}

# Check if docker-compose is available
check_docker_compose() {
    if ! command -v docker > /dev/null 2>&1; then
        log_error "Docker is not installed"
        return 1
    fi
    
    if ! docker compose version > /dev/null 2>&1; then
        log_error "Docker Compose is not available"
        return 1
    fi
    
    return 0
}

# Check if docker-compose.yml exists
check_compose_file() {
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found"
        log_error "Please run this script from the project root directory"
        return 1
    fi
    return 0
}

# --- Pre-flight Checks ---

# Run all pre-flight validation checks
run_preflight_checks() {
    log_info "Running pre-flight checks..."
    
    if ! check_docker_running; then
        return 1
    fi
    
    if ! check_docker_compose; then
        return 1
    fi
    
    if ! check_compose_file; then
        return 1
    fi
    
    log_success "Pre-flight checks passed"
    return 0
}

# --- Error Messages ---

# Show error for invalid level
show_level_error() {
    local level=$1
    log_error "Invalid level: $level"
    echo ""
    echo "Valid levels:"
    for i in $(seq 0 $MAX_LEVEL); do
        echo "  Level $i: ${LEVEL_NAMES[$i]}"
    done
}

# Show error for missing dependencies
show_dependency_error() {
    local level=$1
    local deps="${LEVEL_DEPENDENCIES[$level]}"
    
    log_error "Level $level (${LEVEL_NAMES[$level]}) has unmet dependencies"
    echo ""
    echo "Required dependencies:"
    for dep in $deps; do
        local status=$(get_level_status "$dep")
        echo -e "  Level $dep: ${LEVEL_NAMES[$dep]} - $status"
    done
    echo ""
    echo "Suggestion: Start dependencies first or use auto-start feature"
}

# Show error for conflicting commands
show_conflict_error() {
    log_error "Conflicting management commands detected"
    echo ""
    echo "Management commands are mutually exclusive:"
    echo "  --start           - Start services"
    echo "  --stop            - Stop services"
    echo "  --restart-rebuild - Rebuild and restart"
    echo "  --clean           - Clean all resources"
    echo ""
    echo "You can only use ONE management command at a time"
    echo ""
    echo "Information commands CAN be combined:"
    echo "  -v, --visualize   - Show visualization"
    echo "  -h, --health-check - Run health checks"
    echo "  -l, --logs        - Show logs"
    echo "  -s, --summary     - Show summary"
}