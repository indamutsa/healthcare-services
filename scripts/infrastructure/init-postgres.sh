#!/bin/bash
#
# PostgreSQL Initialization
# Sets up databases for MLflow and Airflow
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script for any local resources
POSTGRES_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- PostgreSQL MLflow Functions ---

# Check if PostgreSQL MLflow is ready
check_postgres_mlflow_ready() {
    if docker exec postgres-mlflow pg_isready -U "$POSTGRES_MLFLOW_USER" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Initialize PostgreSQL MLflow database
initialize_postgres_mlflow() {
    log_info "Initializing PostgreSQL for MLflow..."
    
    # Wait for PostgreSQL to be ready
    local max_retries=30
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if check_postgres_mlflow_ready; then
            log_success "PostgreSQL MLflow is ready"
            break
        fi
        sleep 2
        retry=$((retry + 1))
    done
    
    if [ $retry -eq $max_retries ]; then
        log_error "PostgreSQL MLflow did not start in time"
        return 1
    fi
    
    # Check if database exists
    local db_exists=$(docker exec postgres-mlflow psql -U "$POSTGRES_MLFLOW_USER" \
        -lqt | cut -d \| -f 1 | grep -w "$POSTGRES_MLFLOW_DB" | wc -l)
    
    if [ "$db_exists" -eq 0 ]; then
        log_info "Creating MLflow database..."
        docker exec postgres-mlflow psql -U "$POSTGRES_MLFLOW_USER" \
            -c "CREATE DATABASE $POSTGRES_MLFLOW_DB;" 2>/dev/null || true
        log_success "MLflow database created"
    else
        log_info "MLflow database already exists"
    fi
    
    # Create extensions if needed
    log_info "Setting up database extensions..."
    docker exec postgres-mlflow psql -U "$POSTGRES_MLFLOW_USER" -d "$POSTGRES_MLFLOW_DB" \
        -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" 2>/dev/null || true
    
    log_success "PostgreSQL MLflow initialization complete"
    return 0
}

# Show MLflow database info
show_mlflow_db_info() {
    log_info "MLflow Database Information:"
    echo ""
    
    if check_service_running "postgres-mlflow"; then
        echo "Host: $POSTGRES_MLFLOW_HOST"
        echo "Port: $POSTGRES_MLFLOW_PORT"
        echo "Database: $POSTGRES_MLFLOW_DB"
        echo "User: $POSTGRES_MLFLOW_USER"
        echo ""
        
        # Show database size
        local db_size=$(docker exec postgres-mlflow psql -U "$POSTGRES_MLFLOW_USER" \
            -d "$POSTGRES_MLFLOW_DB" -t -c \
            "SELECT pg_size_pretty(pg_database_size('$POSTGRES_MLFLOW_DB'));" 2>/dev/null | xargs)
        
        echo "Database size: $db_size"
        
        # Show tables
        log_info "Tables:"
        docker exec postgres-mlflow psql -U "$POSTGRES_MLFLOW_USER" \
            -d "$POSTGRES_MLFLOW_DB" -c "\dt" 2>/dev/null | grep -v "^(" | grep -v "^-" || true
    else
        log_error "PostgreSQL MLflow is not running"
        return 1
    fi
    
    echo ""
}

# --- PostgreSQL Airflow Functions ---

# Check if PostgreSQL Airflow is ready
check_postgres_airflow_ready() {
    if docker exec postgres-airflow pg_isready -U "$POSTGRES_AIRFLOW_USER" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Initialize PostgreSQL Airflow database
initialize_postgres_airflow() {
    log_info "Initializing PostgreSQL for Airflow..."
    
    # Wait for PostgreSQL to be ready
    local max_retries=30
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if check_postgres_airflow_ready; then
            log_success "PostgreSQL Airflow is ready"
            break
        fi
        sleep 2
        retry=$((retry + 1))
    done
    
    if [ $retry -eq $max_retries ]; then
        log_error "PostgreSQL Airflow did not start in time"
        return 1
    fi
    
    # Check if database exists
    local db_exists=$(docker exec postgres-airflow psql -U "$POSTGRES_AIRFLOW_USER" \
        -lqt | cut -d \| -f 1 | grep -w "$POSTGRES_AIRFLOW_DB" | wc -l)
    
    if [ "$db_exists" -eq 0 ]; then
        log_info "Creating Airflow database..."
        docker exec postgres-airflow psql -U "$POSTGRES_AIRFLOW_USER" \
            -c "CREATE DATABASE $POSTGRES_AIRFLOW_DB;" 2>/dev/null || true
        log_success "Airflow database created"
    else
        log_info "Airflow database already exists"
    fi
    
    log_success "PostgreSQL Airflow initialization complete"
    return 0
}

# Show Airflow database info
show_airflow_db_info() {
    log_info "Airflow Database Information:"
    echo ""
    
    if check_service_running "postgres-airflow"; then
        echo "Host: $POSTGRES_AIRFLOW_HOST"
        echo "Port: $POSTGRES_AIRFLOW_PORT"
        echo "Database: $POSTGRES_AIRFLOW_DB"
        echo "User: $POSTGRES_AIRFLOW_USER"
        echo ""
        
        # Show database size
        local db_size=$(docker exec postgres-airflow psql -U "$POSTGRES_AIRFLOW_USER" \
            -d "$POSTGRES_AIRFLOW_DB" -t -c \
            "SELECT pg_size_pretty(pg_database_size('$POSTGRES_AIRFLOW_DB'));" 2>/dev/null | xargs)
        
        echo "Database size: $db_size"
    else
        log_error "PostgreSQL Airflow is not running"
        return 1
    fi
    
    echo ""
}

# --- Common Functions ---

# Initialize both databases
initialize_all_postgres() {
    log_info "Initializing all PostgreSQL databases..."
    
    initialize_postgres_mlflow
    initialize_postgres_airflow
    
    log_success "All PostgreSQL databases initialized"
}

# Show all database info
show_all_db_info() {
    show_mlflow_db_info
    echo ""
    show_airflow_db_info
}

# Export functions
export -f initialize_postgres_mlflow
export -f initialize_postgres_airflow
export -f initialize_all_postgres
export -f check_postgres_mlflow_ready
export -f check_postgres_airflow_ready
export -f show_mlflow_db_info
export -f show_airflow_db_info
export -f show_all_db_info