#!/bin/bash
#
# Common Utility Functions
# Provides: logging, Docker operations, wait functions, and helpers
#

# Source configuration (only if not already loaded)
if [ -z "${COMMON_CONFIG_LOADED:-}" ]; then
    UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${UTILS_SCRIPT_DIR}/config.sh"
fi

# --- Logging Functions ---

# Print a styled header
print_header() {
    local message=$1
    echo ""
    echo "=========================================="
    echo "$message"
    echo "=========================================="
    echo ""
}

# Print a level-specific header
print_level_header() {
    local level=$1
    local action=$2
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Level $level: ${LEVEL_NAMES[$level]} ($action)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Log info message
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Log success message
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Log warning message
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Log error message
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Docker Operations ---

# Check if a service is running
check_service_running() {
    local service=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        return 0
    else
        return 1
    fi
}

# Check if all services in a level are running
check_level_running() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    
    for service in $services; do
        if ! check_service_running "$service"; then
            return 1
        fi
    done
    
    return 0
}

# Get level status as a colored string
get_level_status() {
    local level=$1
    if check_level_running "$level"; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${RED}✗ STOPPED${NC}"
    fi
}

# Start services for a level
docker_compose_up() {
    local level=$1
    local force_recreate=${2:-false}
    local services="${LEVEL_SERVICE_NAMES[$level]:-${LEVEL_SERVICES[$level]}}"
    local setup_services="${LEVEL_SETUP_SERVICES[$level]:-}"
    local profile="${LEVEL_PROFILES[$level]}"

    local compose_args=()

    # Add profile if exists
    if [ -n "$profile" ]; then
        compose_args+=(--profile "$profile")
    fi

    # Add services
    compose_args+=(up -d)

    # Add force recreate flag if needed
    if [ "$force_recreate" = true ]; then
        compose_args+=(--force-recreate)
    fi

    # Add service names (both regular and setup services)
    compose_args+=($services $setup_services)

    # Execute docker compose
    docker compose "${compose_args[@]}"
}

# Stop services for a level
docker_compose_down() {
    local level=$1
    local remove_volumes=${2:-false}
    local services="${LEVEL_SERVICE_NAMES[$level]:-${LEVEL_SERVICES[$level]}}"
    local profile="${LEVEL_PROFILES[$level]}"
    
    local compose_args=(stop)
    compose_args+=($services)
    
    # Stop services
    if [ -n "$profile" ]; then
        docker compose --profile "$profile" "${compose_args[@]}"
    else
        docker compose "${compose_args[@]}"
    fi
    
    # Remove containers
    docker compose rm -f $services
    
    # Remove volumes if requested
    if [ "$remove_volumes" = true ]; then
        log_warning "Removing volumes for level $level..."
        # Note: This removes all volumes, be careful
        docker compose down --volumes
    fi
}

# Build images for a level
docker_compose_build() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    local profile="${LEVEL_PROFILES[$level]}"
    
    log_info "Building images for Level $level: ${LEVEL_NAMES[$level]}"
    
    if [ -n "$profile" ]; then
        docker compose --profile "$profile" build $services 2>&1 | \
            grep -E "Building|Successfully|FINISHED" || true
    else
        docker compose build $services 2>&1 | \
            grep -E "Building|Successfully|FINISHED" || true
    fi
}

# --- Wait Functions ---

# Wait for a service to be healthy
wait_for_service() {
    local service=$1
    local timeout=${2:-$DEFAULT_TIMEOUT}
    local elapsed=0
    
    log_info "Waiting for $service to be ready..."
    
    while [ $elapsed -lt $timeout ]; do
        if check_service_running "$service"; then
            log_success "$service is ready"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_error "$service failed to start within ${timeout}s"
    return 1
}

# Wait for multiple services
wait_for_services() {
    local services=$1
    local timeout=${2:-$DEFAULT_TIMEOUT}
    
    for service in $services; do
        wait_for_service "$service" "$timeout" || return 1
    done
    
    return 0
}

# Wait for a level to be ready
wait_for_level() {
    local level=$1
    local timeout=${2:-$DEFAULT_TIMEOUT}
    local services="${LEVEL_SERVICES[$level]}"
    
    log_info "Waiting for Level $level (${LEVEL_NAMES[$level]}) to be ready..."
    
    wait_for_services "$services" "$timeout"
    return $?
}

# --- Dependency Management ---

# Check if all dependencies for a level are running
check_dependencies_running() {
    local level=$1
    local deps="${LEVEL_DEPENDENCIES[$level]}"
    
    for dep in $deps; do
        if ! check_level_running "$dep"; then
            return 1
        fi
    done
    
    return 0
}

# Get list of dependency levels
get_dependency_levels() {
    local level=$1
    echo "${LEVEL_DEPENDENCIES[$level]}"
}

# --- Service Information ---

# Count running services in a level
count_running_services() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    local count=0
    
    for service in $services; do
        if check_service_running "$service"; then
            count=$((count + 1))
        fi
    done
    
    echo "$count"
}

# Count total services in a level
count_total_services() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    echo "$services" | wc -w
}

# --- Validation Helpers ---

# Validate level number
is_valid_level() {
    local level=$1
    if [ "$level" -ge 0 ] && [ "$level" -le "$MAX_LEVEL" ]; then
        return 0
    else
        return 1
    fi
}