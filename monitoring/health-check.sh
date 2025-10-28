#!/bin/bash

# Clinical Trials Service Health Check Script
# Usage: ./health-check.sh [--verbose] [--service <service_name>]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
SERVICE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --service)
            SERVICE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✅ ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ ${message}${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  ${message}${NC}"
            ;;
    esac
}

# Function to check service status
check_service() {
    local service_name=$1
    local container_name=""
    
    case $service_name in
        "clinical-gateway")
            container_name="clinical-gateway"
            health_endpoint="http://localhost:8082/actuator/health"
            ;;
        "lab-processor")
            container_name="lab-processor"
            health_endpoint="http://localhost:8083/actuator/health"
            ;;
        "clinical-mq")
            container_name="clinical-mq"
            ;;
        "spark-master")
            container_name="spark-master"
            health_endpoint="http://localhost:8080"
            ;;
        "spark-worker")
            container_name="spark-worker"
            health_endpoint="http://localhost:8081"
            ;;
        "postgres-mlflow")
            container_name="postgres-mlflow"
            ;;
        "postgres-airflow")
            container_name="postgres-airflow"
            ;;
        "redis")
            container_name="redis"
            ;;
        "minio")
            container_name="minio"
            health_endpoint="http://localhost:9000/minio/health/live"
            ;;
        "kafka")
            container_name="kafka"
            ;;
        "zookeeper")
            container_name="zookeeper"
            ;;
        "prometheus")
            container_name="prometheus"
            health_endpoint="http://localhost:9090/-/healthy"
            ;;
        "grafana")
            container_name="grafana"
            health_endpoint="http://localhost:3000/api/health"
            ;;
        *)
            print_status "ERROR" "Unknown service: $service_name"
            return 1
            ;;
    esac
    
    # Check if container is running
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        print_status "SUCCESS" "${service_name}: Container is running"
    else
        print_status "ERROR" "${service_name}: Container is not running"
        return 1
    fi
    
    # Check container health status
    if [[ $service_name != "clinical-mq" && $service_name != "postgres-mlflow" && $service_name != "postgres-airflow" && $service_name != "redis" && $service_name != "kafka" && $service_name != "zookeeper" ]]; then
        if [[ -n "$health_endpoint" ]]; then
            if curl -s -f "$health_endpoint" > /dev/null 2>&1; then
                print_status "SUCCESS" "${service_name}: Health endpoint responding"
            else
                print_status "ERROR" "${service_name}: Health endpoint not responding"
                return 1
            fi
        fi
    fi
    
    # Service-specific checks
    case $service_name in
        "clinical-mq")
            if docker exec "$container_name" dspmq 2>/dev/null | grep -q "STATUS(Running)"; then
                print_status "SUCCESS" "${service_name}: Queue manager is running"
            else
                print_status "ERROR" "${service_name}: Queue manager is not running"
                return 1
            fi
            ;;
        "postgres-mlflow"|"postgres-airflow")
            if docker exec "$container_name" pg_isready -U postgres > /dev/null 2>&1; then
                print_status "SUCCESS" "${service_name}: Database is accepting connections"
            else
                print_status "ERROR" "${service_name}: Database is not accepting connections"
                return 1
            fi
            ;;
        "redis")
            if docker exec "$container_name" redis-cli ping 2>/dev/null | grep -q "PONG"; then
                print_status "SUCCESS" "${service_name}: Redis is responding"
            else
                print_status "ERROR" "${service_name}: Redis is not responding"
                return 1
            fi
            ;;
        "kafka")
            if docker exec "$container_name" kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
                print_status "SUCCESS" "${service_name}: Kafka is responding"
            else
                print_status "ERROR" "${service_name}: Kafka is not responding"
                return 1
            fi
            ;;
        "zookeeper")
            if docker exec "$container_name" echo "ruok" | nc localhost 2181 | grep -q "imok"; then
                print_status "SUCCESS" "${service_name}: Zookeeper is responding"
            else
                print_status "ERROR" "${service_name}: Zookeeper is not responding"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to check resource usage
check_resources() {
    echo -e "\n${BLUE}📊 Resource Usage Summary:${NC}"
    
    # Container resource usage
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | \
    while read line; do
        if [[ $line == *"NAME"* ]]; then
            echo -e "${BLUE}$line${NC}"
        else
            container_name=$(echo "$line" | awk '{print $1}')
            cpu_perc=$(echo "$line" | awk '{print $2}' | sed 's/%//')
            mem_perc=$(echo "$line" | awk '{print $4}' | sed 's/%//')
            
            if (( $(echo "$cpu_perc > 80" | bc -l) )); then
                echo -e "${RED}$line ⚠️ HIGH CPU${NC}"
            elif (( $(echo "$mem_perc > 80" | bc -l) )); then
                echo -e "${RED}$line ⚠️ HIGH MEMORY${NC}"
            else
                echo "$line"
            fi
        fi
    done
    
    # System resources
    echo -e "\n${BLUE}💻 System Resources:${NC}"
    echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2 " (" $5 ")"}')"
    echo "Disk: $(df -h / | awk 'NR==2{print $3"/"$2 " (" $5 ")"}')"
}

# Function to check network connectivity
check_network() {
    echo -e "\n${BLUE}🌐 Network Connectivity:${NC}"
    
    # Check internal network
    if docker network inspect clinical-trials-service_mlops-network > /dev/null 2>&1; then
        print_status "SUCCESS" "Docker network is available"
    else
        print_status "ERROR" "Docker network is not available"
    fi
    
    # Check port availability
    ports=("8082" "8083" "8080" "8081" "5432" "5433" "6379" "9000" "9090" "3000")
    for port in "${ports[@]}"; do
        if netstat -tulpn | grep ":$port " > /dev/null 2>&1; then
            print_status "SUCCESS" "Port $port is listening"
        else
            print_status "WARNING" "Port $port is not listening"
        fi
    done
}

# Function to check data flow
check_data_flow() {
    echo -e "\n${BLUE}📈 Data Flow Status:${NC}"
    
    # Check Kafka topics
    if docker ps | grep -q kafka; then
        if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
            print_status "SUCCESS" "Kafka is operational"
            
            # List topics
            topics=$(docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null)
            if [[ -n "$topics" ]]; then
                echo "   Available topics: $topics"
            fi
        else
            print_status "ERROR" "Kafka is not operational"
        fi
    fi
    
    # Check MQ queues
    if docker ps | grep -q clinical-mq; then
        if docker exec clinical-mq dspmq > /dev/null 2>&1; then
            print_status "SUCCESS" "IBM MQ is operational"
        else
            print_status "ERROR" "IBM MQ is not operational"
        fi
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Clinical Trials Service Health Check${NC}"
    echo "=========================================="
    echo "Timestamp: $(date)"
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_status "ERROR" "Docker is not running"
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose > /dev/null 2>&1; then
        print_status "ERROR" "docker-compose is not available"
        exit 1
    fi
    
    # Service checks
    if [[ -n "$SERVICE" ]]; then
        # Check specific service
        echo -e "\n${BLUE}🔍 Checking service: $SERVICE${NC}"
        check_service "$SERVICE"
    else
        # Check all services
        echo -e "\n${BLUE}🔍 Service Status:${NC}"
        
        services=(
            "clinical-gateway"
            "lab-processor" 
            "clinical-mq"
            "spark-master"
            "spark-worker"
            "postgres-mlflow"
            "postgres-airflow"
            "redis"
            "minio"
            "kafka"
            "zookeeper"
            "prometheus"
            "grafana"
        )
        
        failed_services=()
        
        for service in "${services[@]}"; do
            if ! check_service "$service"; then
                failed_services+=("$service")
            fi
        done
        
        # Summary
        echo -e "\n${BLUE}📋 Summary:${NC}"
        if [[ ${#failed_services[@]} -eq 0 ]]; then
            print_status "SUCCESS" "All services are healthy!"
        else
            print_status "ERROR" "Failed services: ${failed_services[*]}"
        fi
    fi
    
    # Additional checks
    check_resources
    check_network
    check_data_flow
    
    echo -e "\n${GREEN}✅ Health check completed at $(date)${NC}"
}

# Run main function
main "$@"