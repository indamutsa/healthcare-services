#!/bin/bash
#
# MinIO Initialization
# Creates buckets and configures policies
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script for any local resources
MINIO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- MinIO Functions ---

# Configure MinIO client alias
configure_minio_alias() {
    log_info "Configuring MinIO client alias..."
    
    # Try to configure alias on the minio container
    if docker exec minio mc alias set myminio \
        http://localhost:9000 "$MINIO_USER" "$MINIO_PASSWORD" 2>/dev/null; then
        log_success "MinIO client alias configured"
        return 0
    else
        log_warning "Failed to configure MinIO alias (container may still be starting)"
        return 1
    fi
}

# Check if a bucket exists
check_bucket_exists() {
    local bucket_name=$1
    
    if docker exec minio mc ls "myminio/${bucket_name}" 2>/dev/null | head -1 >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Create a bucket
create_bucket() {
    local bucket_name=$1
    
    log_info "Creating bucket: $bucket_name"
    
    if check_bucket_exists "$bucket_name"; then
        log_info "Bucket '$bucket_name' already exists"
        return 0
    fi
    
    if docker exec minio mc mb "myminio/${bucket_name}" --ignore-existing 2>/dev/null; then
        log_success "Bucket '$bucket_name' created"
        return 0
    else
        log_error "Failed to create bucket '$bucket_name'"
        return 1
    fi
}

# Set bucket policy
set_bucket_policy() {
    local bucket_name=$1
    local policy=${2:-download}  # download, upload, public, or none
    
    log_info "Setting policy '$policy' for bucket: $bucket_name"
    
    if docker exec minio mc anonymous set "$policy" "myminio/${bucket_name}" 2>/dev/null; then
        log_success "Policy set for bucket '$bucket_name'"
        return 0
    else
        log_warning "Failed to set policy for bucket '$bucket_name'"
        return 1
    fi
}

# Create folder structure in a bucket
create_bucket_structure() {
    local bucket_name=$1
    shift
    local folders=("$@")
    
    log_info "Creating folder structure in bucket: $bucket_name"
    
    for folder in "${folders[@]}"; do
        # Create an empty file to establish the folder
        docker exec minio mc put /dev/null "myminio/${bucket_name}/${folder}/.keep" 2>/dev/null || true
    done
    
    log_success "Folder structure created"
}

# Initialize MinIO with all required buckets
initialize_minio() {
    log_info "Initializing MinIO..."
    
    # Wait for MinIO to be ready
    local max_retries=30
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if check_service_running "minio"; then
            sleep 2  # Give it a moment to fully start
            break
        fi
        sleep 2
        retry=$((retry + 1))
    done
    
    if [ $retry -eq $max_retries ]; then
        log_error "MinIO did not start in time"
        return 1
    fi
    
    # Configure alias
    configure_minio_alias || return 1
    
    # Create buckets
    for bucket in $MINIO_BUCKETS; do
        create_bucket "$bucket"
        set_bucket_policy "$bucket" "download"
    done
    
    # Create folder structure for clinical-mlops bucket
    log_info "Creating folder structure for clinical-mlops bucket..."
    create_bucket_structure "clinical-mlops" \
        "raw" \
        "processed" \
        "features/online" \
        "features/offline" \
        "models" \
        "artifacts"
    
    # Verify buckets
    log_info "Verifying buckets..."
    echo ""
    docker exec minio mc ls myminio/ 2>/dev/null || true
    echo ""
    
    log_success "MinIO initialization complete"
    return 0
}

# Check MinIO health
check_minio_health() {
    if curl -sf "${MINIO_ENDPOINT}/minio/health/live" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# List all buckets
list_minio_buckets() {
    log_info "MinIO buckets:"
    echo ""
    
    if check_service_running "minio"; then
        configure_minio_alias
        docker exec minio mc ls myminio/ 2>/dev/null || echo "  No buckets found"
    else
        log_error "MinIO is not running"
        return 1
    fi
    
    echo ""
}

# Show bucket contents
show_bucket_contents() {
    local bucket_name=$1
    local path=${2:-""}
    
    log_info "Contents of $bucket_name/$path:"
    echo ""
    
    if check_service_running "minio"; then
        configure_minio_alias
        docker exec minio mc ls "myminio/${bucket_name}/${path}" --recursive 2>/dev/null | head -20
    else
        log_error "MinIO is not running"
        return 1
    fi
    
    echo ""
}

# Export functions
export -f initialize_minio
export -f check_minio_health
export -f list_minio_buckets
export -f show_bucket_contents
export -f create_bucket
export -f configure_minio_alias
export -f check_bucket_exists