#!/bin/bash
#
# Real-time Resource Monitoring by Level
#

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Level Definitions (matching manage_pipeline.sh) ---
declare -A LEVEL_SERVICES
declare -A LEVEL_NAMES

# Level 0: Infrastructure
LEVEL_SERVICES[0]="minio minio-setup postgres-mlflow postgres-airflow redis redis-insight zookeeper kafka kafka-ui"
LEVEL_NAMES[0]="Infrastructure"

# Level 1: Data Ingestion
LEVEL_SERVICES[1]="kafka-producer kafka-consumer clinical-mq clinical-data-gateway lab-results-processor clinical-data-generator"
LEVEL_NAMES[1]="Data Ingestion"

# Level 2: Data Processing
LEVEL_SERVICES[2]="spark-master spark-worker spark-streaming spark-batch"
LEVEL_NAMES[2]="Data Processing"

# Level 3: Feature Engineering
LEVEL_SERVICES[3]="feature-engineering"
LEVEL_NAMES[3]="Feature Engineering"

# Level 4: ML Pipeline
LEVEL_SERVICES[4]="mlflow-server ml-training model-serving"
LEVEL_NAMES[4]="ML Pipeline"

# Level 5: Observability
LEVEL_SERVICES[5]="airflow-init airflow-webserver airflow-scheduler prometheus grafana monitoring-service opensearch opensearch-dashboards data-prepper filebeat"
LEVEL_NAMES[5]="Observability"

MAX_LEVEL=5

# Check if bc is available for calculations
check_bc() {
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}Error: 'bc' command not found. Installing...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command -v yum &> /dev/null; then
            sudo yum install -y bc
        else
            echo -e "${RED}Please install 'bc' manually to continue${NC}"
            exit 1
        fi
    fi
}

# Function to check if service is running
check_service_running() {
    local service=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        return 0
    else
        return 1
    fi
}

# Function to get service stats
get_service_stats() {
    local service=$1
    if check_service_running "$service"; then
        local stats=$(docker stats --no-stream --format "{{.CPUPerc}} {{.MemUsage}} {{.NetIO}} {{.BlockIO}}" "$service" 2>/dev/null | head -1)
        if [ -n "$stats" ]; then
            local cpu=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
            local mem=$(echo "$stats" | awk '{print $2}' | sed 's/[A-Za-z]*//g')
            local net_io=$(echo "$stats" | awk '{print $3 " " $4}')
            local block_io=$(echo "$stats" | awk '{print $5 " " $6}')
            echo "$cpu $mem $net_io $block_io"
        else
            echo "0 0 0B/0B 0B/0B"
        fi
    else
        echo "0 0 0B/0B 0B/0B"
    fi
}

# Function to format memory
format_memory() {
    local mem_mb=$1
    if (( $(echo "$mem_mb > 1024" | bc -l) )); then
        echo "$(echo "scale=1; $mem_mb / 1024" | bc) GiB"
    else
        echo "${mem_mb} MiB"
    fi
}

# Function to monitor specific level
monitor_level() {
    local level=$1
    local services="${LEVEL_SERVICES[$level]}"
    local total_cpu=0
    local total_mem=0
    local running_count=0
    local service_count=0
    
    echo -e "${BLUE}Level $level: ${LEVEL_NAMES[$level]}${NC}"
    
    for service in $services; do
        ((service_count++))
        if check_service_running "$service"; then
            local stats=$(get_service_stats "$service")
            local cpu=$(echo "$stats" | awk '{print $1}')
            local mem=$(echo "$stats" | awk '{print $2}')
            local net_io=$(echo "$stats" | awk '{print $3 " " $4}')
            local block_io=$(echo "$stats" | awk '{print $5 " " $6}')
            
            # Only add to totals if we got valid numbers
            if [[ $cpu =~ ^[0-9.]+$ ]] && [[ $mem =~ ^[0-9.]+$ ]]; then
                total_cpu=$(echo "$total_cpu + $cpu" | bc -l)
                total_mem=$(echo "$total_mem + $mem" | bc -l)
                ((running_count++))
                
                # Color code based on CPU usage
                local cpu_color=$GREEN
                if (( $(echo "$cpu > 80" | bc -l) )); then
                    cpu_color=$RED
                elif (( $(echo "$cpu > 50" | bc -l) )); then
                    cpu_color=$YELLOW
                fi
                
                # Color code based on memory usage
                local mem_color=$GREEN
                if (( $(echo "$mem > 1024" | bc -l) )); then
                    mem_color=$YELLOW
                elif (( $(echo "$mem > 2048" | bc -l) )); then
                    mem_color=$RED
                fi
                
                echo -e "  ${GREEN}✓${NC} $service: ${cpu_color}CPU: ${cpu}%${NC} ${mem_color}MEM: $(format_memory $mem)${NC}"
            else
                echo -e "  ${GREEN}✓${NC} $service: ${YELLOW}Stats unavailable${NC}"
                ((running_count++))
            fi
        else
            echo -e "  ${RED}✗${NC} $service: ${RED}STOPPED${NC}"
        fi
    done
    
    # Calculate averages
    if [ $running_count -gt 0 ]; then
        local avg_cpu=$(echo "scale=1; $total_cpu / $running_count" | bc -l)
        local avg_mem=$(echo "scale=1; $total_mem / $running_count" | bc -l)
        
        echo -e "  ${CYAN}Summary:${NC} $running_count/$service_count services | ${CYAN}Avg CPU:${NC} ${avg_cpu}% | ${CYAN}Avg MEM:${NC} $(format_memory $avg_mem)"
    else
        echo -e "  ${RED}No services running${NC}"
    fi
    echo ""
}

# Function to show quick overview
show_overview() {
    echo -e "${CYAN}Level Overview:${NC}"
    for level in $(seq 0 $MAX_LEVEL); do
        local services="${LEVEL_SERVICES[$level]}"
        local running_count=0
        local service_count=0
        
        for service in $services; do
            ((service_count++))
            if check_service_running "$service"; then
                ((running_count++))
            fi
        done
        
        local status_color=$GREEN
        if [ $running_count -eq 0 ]; then
            status_color=$RED
        elif [ $running_count -lt $service_count ]; then
            status_color=$YELLOW
        fi
        
        echo -e "  Level $level: ${LEVEL_NAMES[$level]}: ${status_color}$running_count/$service_count running${NC}"
    done
    echo ""
}

# Function to show system resources
show_system_resources() {
    echo -e "${CYAN}System Resources:${NC}"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_color=$GREEN
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        cpu_color=$RED
    elif (( $(echo "$cpu_usage > 50" | bc -l) )); then
        cpu_color=$YELLOW
    fi
    
    # Memory usage
    local mem_total=$(free -m | awk '/Mem:/ {print $2}')
    local mem_used=$(free -m | awk '/Mem:/ {print $3}')
    local mem_percent=$(echo "scale=1; ($mem_used * 100) / $mem_total" | bc -l)
    local mem_color=$GREEN
    if (( $(echo "$mem_percent > 80" | bc -l) )); then
        mem_color=$RED
    elif (( $(echo "$mem_percent > 50" | bc -l) )); then
        mem_color=$YELLOW
    fi
    
    # Disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_color=$GREEN
    if [ "$disk_usage" -gt 80 ]; then
        disk_color=$RED
    elif [ "$disk_usage" -gt 50 ]; then
        disk_color=$YELLOW
    fi
    
    echo -e "  CPU: ${cpu_color}${cpu_usage}%${NC} | Memory: ${mem_color}${mem_percent}%${NC} | Disk: ${disk_color}${disk_usage}%${NC}"
    echo ""
}

show_usage() {
    cat << EOF
${CYAN}Clinical MLOps - Resource Monitor${NC}

${GREEN}Usage:${NC}
  $0 [options]

${GREEN}Options:${NC}
  -l, --level <N>      Monitor specific level (0-$MAX_LEVEL)
  -o, --overview       Show overview only (no detailed stats)
  -s, --system         Show system resources only
  -i, --interval <N>   Set refresh interval in seconds (default: 3)
  -h, --help           Show this help message

${GREEN}Examples:${NC}
  # Monitor all levels (default)
  $0
  
  # Monitor specific level
  $0 --level 0
  $0 --level 4
  
  # Overview only
  $0 --overview
  
  # System resources only
  $0 --system
  
  # Custom interval
  $0 --interval 5

${GREEN}Levels:${NC}
  0: Infrastructure (minio, kafka, redis, postgres)
  1: Data Ingestion (kafka producers/consumers, data gateways)
  2: Data Processing (spark master/worker, streaming, batch)
  3: Feature Engineering (feature service)
  4: ML Pipeline (mlflow, training, model serving)
  5: Observability (airflow, prometheus, grafana, opensearch)

EOF
}

# Main monitoring loop
main_monitor() {
    local level_to_monitor=""
    local mode="full"
    local interval=3
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--level)
                level_to_monitor="$2"
                shift
                shift
                ;;
            -o|--overview)
                mode="overview"
                shift
                ;;
            -s|--system)
                mode="system"
                shift
                ;;
            -i|--interval)
                interval="$2"
                shift
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check for bc
    check_bc
    
    while true; do
        clear
        echo "═══════════════════════════════════════════════════════════════════"
        echo -e "${CYAN}Clinical MLOps - Resource Monitor${NC} (refreshes every ${interval}s)"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
        
        case $mode in
            overview)
                show_system_resources
                show_overview
                ;;
            system)
                show_system_resources
                ;;
            full)
                show_system_resources
                if [ -n "$level_to_monitor" ]; then
                    # Monitor specific level
                    if [ "$level_to_monitor" -ge 0 ] && [ "$level_to_monitor" -le $MAX_LEVEL ]; then
                        monitor_level "$level_to_monitor"
                    else
                        echo -e "${RED}Invalid level: $level_to_monitor. Must be 0-$MAX_LEVEL${NC}"
                        exit 1
                    fi
                else
                    # Monitor all levels
                    for level in $(seq 0 $MAX_LEVEL); do
                        monitor_level "$level"
                    done
                fi
                ;;
        esac
        
        echo "═══════════════════════════════════════════════════════════════════"
        echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
        echo "═══════════════════════════════════════════════════════════════════"
        sleep "$interval"
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Monitoring stopped${NC}"; exit 0' INT

# Run main function
main_monitor "$@"