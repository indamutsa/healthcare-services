#!/bin/bash
# Quick health check for all services

echo "🔍 Checking service health..."
echo ""

# Check HTTP endpoints
check_url() {
    url=$1
    name=$2
    if curl -f -s "$url" > /dev/null; then
        echo "✅ $name - OK"
    else
        echo "❌ $name - FAILED"
    fi
}

check_url "http://localhost:9001/minio/health/live" "MinIO"
check_url "http://localhost:8090" "Kafka UI"
check_url "http://localhost:8080" "Spark Master"
check_url "http://localhost:5000/health" "MLflow"
check_url "http://localhost:9090/-/healthy" "Prometheus"
check_url "http://localhost:3000/api/health" "Grafana"
check_url "http://localhost:5601/api/status" "OpenSearch Dashboards"

echo ""
echo "🔍 Checking Kafka..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1 && echo "✅ Kafka - OK" || echo "❌ Kafka - FAILED"

echo ""
echo "🔍 Checking containers..."
docker ps --format "{{.Names}}\t{{.Status}}" | grep -E "(kafka-producer|kafka-consumer)" | while read line; do
    echo "  $line"
done