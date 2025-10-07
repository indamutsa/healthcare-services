#!/bin/bash
# Complete service status overview

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_header "Docker Compose Services"
docker-compose ps

print_header "Running Containers by Category"

echo -e "${YELLOW}📊 Data Pipeline:${NC}"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep -E "(kafka|zookeeper|minio)"

echo ""
echo -e "${YELLOW}⚡ Processing:${NC}"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep -E "(spark|airflow)"

echo ""
echo -e "${YELLOW}🧠 ML Platform:${NC}"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep -E "(mlflow|redis|postgres)"

echo ""
echo -e "${YELLOW}📈 Monitoring:${NC}"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep -E "(prometheus|grafana|opensearch|kibana)"

echo ""
echo -e "${YELLOW}🏥 Clinical Apps:${NC}"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep -E "(clinical|lab-processor)"

print_header "Service Health Checks"

check_health() {
    container=$1
    if docker ps --filter "name=$container" --filter "health=healthy" | grep -q $container; then
        echo -e "  ${GREEN}✓${NC} $container"
    elif docker ps --filter "name=$container" --filter "health=unhealthy" | grep -q $container; then
        echo -e "  ${RED}✗${NC} $container (unhealthy)"
    elif docker ps --filter "name=$container" | grep -q $container; then
        echo -e "  ${YELLOW}◐${NC} $container (starting)"
    else
        echo -e "  ${RED}✗${NC} $container (not running)"
    fi
}

echo "Core Services:"
check_health "kafka"
check_health "zookeeper"
check_health "minio"
check_health "mlflow-server"
check_health "spark-master"
check_health "spark-worker"

echo ""
echo "Applications:"
check_health "kafka-producer"
check_health "kafka-consumer"
check_health "kafka-ui"

print_header "Port Mappings"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(kafka|minio|spark|mlflow|grafana|prometheus|opensearch|airflow|clinical)"

print_header "Resource Usage"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -20



docker logs kafka-producer --tail 20
docker logs kafka-consumer --tail 20


echo ""
echo -e "${GREEN}✅ Status check complete!${NC}"
echo ""
echo "View logs: docker-compose logs -f <service-name>"
echo "Restart service: docker-compose restart <service-name>"
echo "Full restart: docker-compose down && docker-compose up -d"