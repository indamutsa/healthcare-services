#!/bin/bash
#
# Kafka Initialization
# Creates topics and configures Kafka
#
# Note: Common utilities must be sourced before this script

# Get the directory of this script for any local resources
KAFKA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Kafka Configuration ---

# Default topic configuration
DEFAULT_PARTITIONS=3
DEFAULT_REPLICATION_FACTOR=1
DEFAULT_RETENTION_MS=604800000  # 7 days in milliseconds

# --- Kafka Functions ---

# Check if Kafka is ready
check_kafka_ready() {
    if docker exec kafka kafka-broker-api-versions \
        --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for Kafka to be ready
wait_for_kafka() {
    local timeout=${1:-$DEFAULT_TIMEOUT}
    local elapsed=0
    
    log_info "Waiting for Kafka to be ready..."
    
    while [ $elapsed -lt $timeout ]; do
        if check_kafka_ready; then
            log_success "Kafka is ready"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_error "Kafka failed to start within ${timeout}s"
    return 1
}

# Check if a topic exists
check_topic_exists() {
    local topic_name=$1
    
    if docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --list 2>/dev/null | grep -q "^${topic_name}$"; then
        return 0
    else
        return 1
    fi
}

# Create a single topic
create_topic() {
    local topic_name=$1
    local partitions=${2:-$DEFAULT_PARTITIONS}
    local replication_factor=${3:-$DEFAULT_REPLICATION_FACTOR}
    local retention_ms=${4:-$DEFAULT_RETENTION_MS}
    
    log_info "Creating topic: $topic_name"
    
    # Check if topic already exists
    if check_topic_exists "$topic_name"; then
        log_info "Topic '$topic_name' already exists"
        return 0
    fi
    
    # Create the topic
    if docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --create \
        --topic "$topic_name" \
        --partitions "$partitions" \
        --replication-factor "$replication_factor" \
        --config retention.ms="$retention_ms" 2>/dev/null; then
        log_success "Topic '$topic_name' created"
        return 0
    else
        log_error "Failed to create topic '$topic_name'"
        return 1
    fi
}

# Delete a topic
delete_topic() {
    local topic_name=$1
    
    log_warning "Deleting topic: $topic_name"
    
    if ! check_topic_exists "$topic_name"; then
        log_info "Topic '$topic_name' does not exist"
        return 0
    fi
    
    if docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --delete \
        --topic "$topic_name" 2>/dev/null; then
        log_success "Topic '$topic_name' deleted"
        return 0
    else
        log_error "Failed to delete topic '$topic_name'"
        return 1
    fi
}

# Describe a topic
describe_topic() {
    local topic_name=$1
    
    log_info "Topic details: $topic_name"
    echo ""
    
    if ! check_topic_exists "$topic_name"; then
        log_error "Topic '$topic_name' does not exist"
        return 1
    fi
    
    docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --describe \
        --topic "$topic_name" 2>/dev/null
    
    echo ""
}

# List all topics
list_topics() {
    log_info "Kafka topics:"
    echo ""
    
    if ! check_kafka_ready; then
        log_error "Kafka is not running"
        return 1
    fi
    
    local topics=$(docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --list 2>/dev/null)
    
    if [ -z "$topics" ]; then
        echo "  No topics found"
    else
        echo "$topics" | while read -r topic; do
            if [ -n "$topic" ]; then
                # Get partition count
                local partitions=$(docker exec kafka kafka-topics \
                    --bootstrap-server localhost:9092 \
                    --describe \
                    --topic "$topic" 2>/dev/null | grep -c "Partition:")
                
                echo "  • $topic (partitions: $partitions)"
            fi
        done
    fi
    
    echo ""
}

# Create all clinical pipeline topics
create_clinical_topics() {
    log_info "Creating clinical pipeline topics..."
    echo ""
    
    # Patient vitals - high volume, real-time data
    create_topic "patient-vitals" 6 1 604800000
    
    # Lab results - medium volume
    create_topic "lab-results" 3 1 2592000000  # 30 days
    
    # Clinical events - lower volume, longer retention
    create_topic "clinical-events" 3 1 7776000000  # 90 days
    
    # Alerts and notifications - low volume
    create_topic "clinical-alerts" 2 1 2592000000  # 30 days
    
    # Feature store updates
    create_topic "feature-updates" 3 1 604800000  # 7 days
    
    # Model predictions
    create_topic "model-predictions" 3 1 604800000  # 7 days
    
    # Data quality events
    create_topic "data-quality-events" 2 1 2592000000  # 30 days
    
    echo ""
    log_success "Clinical topics created"
}

# Initialize Kafka with all required topics
initialize_kafka() {
    log_info "Initializing Kafka..."
    
    # Wait for Kafka to be ready
    if ! wait_for_kafka 60; then
        return 1
    fi
    
    # Create clinical topics
    create_clinical_topics
    
    # List all topics
    echo ""
    list_topics
    
    log_success "Kafka initialization complete"
    return 0
}

# Get topic message count (approximation)
get_topic_message_count() {
    local topic_name=$1
    
    if ! check_topic_exists "$topic_name"; then
        echo "0"
        return
    fi
    
    # Get the current offset for all partitions (this is an approximation)
    docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$topic_name" \
        --time -1 2>/dev/null | \
        awk -F: '{sum += $3} END {print sum}'
}

# Show topic statistics
show_topic_stats() {
    log_info "Topic Statistics:"
    echo ""
    
    if ! check_kafka_ready; then
        log_error "Kafka is not running"
        return 1
    fi
    
    # Get list of topics
    local topics=$(docker exec kafka kafka-topics \
        --bootstrap-server localhost:9092 \
        --list 2>/dev/null)
    
    if [ -z "$topics" ]; then
        echo "  No topics found"
        return 0
    fi
    
    # Print header
    printf "  %-30s %-12s %-15s\n" "Topic" "Partitions" "Messages (approx)"
    printf "  %-30s %-12s %-15s\n" "-----" "----------" "----------------"
    
    # Print stats for each topic
    echo "$topics" | while read -r topic; do
        if [ -n "$topic" ]; then
            local partitions=$(docker exec kafka kafka-topics \
                --bootstrap-server localhost:9092 \
                --describe \
                --topic "$topic" 2>/dev/null | grep -c "Partition:")
            
            local messages=$(get_topic_message_count "$topic")
            
            printf "  %-30s %-12s %-15s\n" "$topic" "$partitions" "$messages"
        fi
    done
    
    echo ""
}

# Consume messages from a topic (for testing)
consume_topic() {
    local topic_name=$1
    local max_messages=${2:-10}
    
    log_info "Consuming from topic: $topic_name (max $max_messages messages)"
    echo ""
    
    if ! check_topic_exists "$topic_name"; then
        log_error "Topic '$topic_name' does not exist"
        return 1
    fi
    
    docker exec kafka kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic "$topic_name" \
        --from-beginning \
        --max-messages "$max_messages" 2>/dev/null
    
    echo ""
}

# Reset consumer group offsets
reset_consumer_group() {
    local group_id=$1
    local topic_name=$2
    
    log_warning "Resetting consumer group: $group_id for topic: $topic_name"
    
    docker exec kafka kafka-consumer-groups \
        --bootstrap-server localhost:9092 \
        --group "$group_id" \
        --topic "$topic_name" \
        --reset-offsets \
        --to-earliest \
        --execute 2>/dev/null
    
    log_success "Consumer group reset"
}

# List consumer groups
list_consumer_groups() {
    log_info "Consumer groups:"
    echo ""
    
    if ! check_kafka_ready; then
        log_error "Kafka is not running"
        return 1
    fi
    
    docker exec kafka kafka-consumer-groups \
        --bootstrap-server localhost:9092 \
        --list 2>/dev/null | while read -r group; do
        if [ -n "$group" ]; then
            echo "  • $group"
        fi
    done
    
    echo ""
}

# Describe consumer group
describe_consumer_group() {
    local group_id=$1
    
    log_info "Consumer group details: $group_id"
    echo ""
    
    docker exec kafka kafka-consumer-groups \
        --bootstrap-server localhost:9092 \
        --group "$group_id" \
        --describe 2>/dev/null
    
    echo ""
}

# Export functions
export -f initialize_kafka
export -f wait_for_kafka
export -f check_kafka_ready
export -f create_topic
export -f delete_topic
export -f list_topics
export -f describe_topic
export -f create_clinical_topics
export -f show_topic_stats
export -f get_topic_message_count
export -f consume_topic
export -f list_consumer_groups
export -f describe_consumer_group
export -f reset_consumer_group
export -f check_topic_exists