#!/bin/bash

run_debug_commands() {
    local target_level=$1
    echo "Debug Commands - Level $target_level"
    echo "==============================="
    echo "Timestamp: $(date)"
    echo "Target Level: $target_level"
    
    # Validate target level
    if ! [[ "$target_level" =~ ^[0-6]$ ]]; then
        echo "ERROR: Invalid debug level. Must be 0-6"
        return 1
    fi
    
    # Level 0: Basic system status
    if [ "$target_level" -ge 0 ]; then
        echo ""
        echo "Debug Level: System Status"
        echo "=========================="
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime -p 2>/dev/null || echo 'uptime command not available')"
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose ps 2>/dev/null || echo "  Docker Compose not available or no containers running"
        else
            echo "  Docker Compose not installed"
        fi
    fi
    
    # Level 1: Service health
    if [ "$target_level" -ge 1 ]; then
        echo ""
        echo "Debug Level: Service Health"
        echo "==========================="
        
        # Infrastructure services
        echo "Infrastructure Services:"
        
        # MinIO
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:9000/minio/health/live > /dev/null 2>&1; then
                echo "  MinIO: Healthy"
            else
                echo "  MinIO: Unhealthy (connection failed)"
            fi
        else
            echo "  MinIO: Check skipped (curl not available)"
        fi
        
        # PostgreSQL
        if docker ps | grep -q postgres-mlflow; then
            if docker exec postgres-mlflow pg_isready -U postgres > /dev/null 2>&1; then
                echo "  PostgreSQL: Healthy"
            else
                echo "  PostgreSQL: Unhealthy (connection failed)"
            fi
        else
            echo "  PostgreSQL: Container not running"
        fi
        
        # Redis
        if docker ps | grep -q redis; then
            if docker exec redis redis-cli ping > /dev/null 2>&1; then
                echo "  Redis: Healthy"
            else
                echo "  Redis: Unhealthy (connection failed)"
            fi
        else
            echo "  Redis: Container not running"
        fi
        
        # Clinical services
        echo ""
        echo "Clinical Services:"
        
        # Clinical Gateway
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:8082/actuator/health > /dev/null 2>&1; then
                echo "  Clinical Gateway: Healthy"
            else
                echo "  Clinical Gateway: Unhealthy (connection failed)"
            fi
        else
            echo "  Clinical Gateway: Check skipped (curl not available)"
        fi
        
        # Lab Processor
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:8083/actuator/health > /dev/null 2>&1; then
                echo "  Lab Processor: Healthy"
            else
                echo "  Lab Processor: Unhealthy (connection failed)"
            fi
        else
            echo "  Lab Processor: Check skipped (curl not available)"
        fi
        
        # Processing services
        echo ""
        echo "Processing Services:"
        
        # Spark Master
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
                echo "  Spark Master: Healthy"
            else
                echo "  Spark Master: Unhealthy (connection failed)"
            fi
        else
            echo "  Spark Master: Check skipped (curl not available)"
        fi
        
        # Spark Worker
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:8081 > /dev/null 2>&1; then
                echo "  Spark Worker: Healthy"
            else
                echo "  Spark Worker: Unhealthy (connection failed)"
            fi
        else
            echo "  Spark Worker: Check skipped (curl not available)"
        fi
    fi
    
    # Level 2: Resource monitoring
    if [ "$target_level" -ge 2 ]; then
        echo ""
        echo "Debug Level: Resource Monitoring"
        echo "================================="
        
        echo "Container Resource Usage:"
        if command -v docker >/dev/null 2>&1; then
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || echo "  Docker stats command failed"
        else
            echo "  Docker not available"
        fi
        
        echo ""
        echo "System Resources:"
        if command -v free >/dev/null 2>&1; then
            echo "  Memory: $(free -h 2>/dev/null | awk 'NR==2{print $3"/"$2 " (" $5 ")"}' || echo 'memory info unavailable')'"
        else
            echo "  Memory: free command not available"
        fi
        
        if command -v df >/dev/null 2>&1; then
            echo "  Disk: $(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2 " (" $5 ")"}' || echo 'disk info unavailable')'"
        else
            echo "  Disk: df command not available"
        fi
    fi
    
    # Level 3: Network analysis
    if [ "$target_level" -ge 3 ]; then
        echo ""
        echo "Debug Level: Network Analysis"
        echo "============================="
        
        echo "Network Port Status:"
        if command -v timeout >/dev/null 2>&1 && command -v bash >/dev/null 2>&1; then
            echo "  MinIO (9000): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/9000' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  PostgreSQL (5432): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/5432' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Redis (6379): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/6379' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Kafka (9092): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/9092' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Clinical Gateway (8082): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/8082' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Lab Processor (8083): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/8083' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Spark Master (8080): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/8080' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Spark Worker (8081): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/8081' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  MLflow (5000): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/5000' 2>/dev/null && echo "Open" || echo "Closed")"
            echo "  Model Serving (8000): $(timeout 1 bash -c 'echo > /dev/tcp/localhost/8000' 2>/dev/null && echo "Open" || echo "Closed")"
        else
            echo "  Port checks skipped (timeout or bash not available)"
        fi
        
        echo ""
        echo "Network Connectivity:"
        if command -v ping >/dev/null 2>&1; then
            echo "  Internet: $(ping -c 1 -W 1 8.8.8.8 > /dev/null 2>&1 && echo "Connected" || echo "Disconnected")"
        else
            echo "  Internet: ping command not available"
        fi
        
        if command -v docker >/dev/null 2>&1; then
            echo "  Docker Network: $(docker network ls 2>/dev/null | grep clinical-trials > /dev/null && echo "Active" || echo "Inactive")"
        else
            echo "  Docker Network: Docker not available"
        fi
        
        echo ""
        echo "Container Network Status:"
        if command -v docker >/dev/null 2>&1; then
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -10 || echo "  Docker ps command failed"
        else
            echo "  Docker not available"
        fi
    fi
    
    # Level 4: Data flow analysis
    if [ "$target_level" -ge 4 ]; then
        echo ""
        echo "Debug Level: Data Flow Analysis"
        echo "================================"
        
        echo "Kafka Topics:"
        if command -v docker >/dev/null 2>&1 && docker ps | grep -q kafka; then
            if docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null | head -10; then
                echo "  Kafka topics listed above"
            else
                echo "  Kafka not accessible or no topics"
            fi
        else
            echo "  Kafka container not running"
        fi
        
        echo ""
        echo "Message Queue Status:"
        if command -v docker >/dev/null 2>&1; then
            if docker ps | grep -q ibm-mq; then
                echo "  IBM MQ: Running"
            else
                echo "  IBM MQ: Not running"
            fi
        else
            echo "  IBM MQ: Docker not available"
        fi
        
        echo ""
        echo "Data Pipeline Status:"
        if command -v docker >/dev/null 2>&1 && docker ps | grep -q minio-mlops; then
            echo "  MinIO Buckets: $(docker exec minio-mlops mc ls myminio/ 2>/dev/null | wc -l || echo '0') buckets"
        else
            echo "  MinIO Buckets: MinIO container not running"
        fi
        
        if command -v docker >/dev/null 2>&1 && docker ps | grep -q postgres-mlflow; then
            echo "  PostgreSQL Tables: $(docker exec postgres-mlflow psql -U postgres -d mlflow_db -t -c 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''public'\'';' 2>/dev/null | tr -d ' ' || echo '0') tables"
        else
            echo "  PostgreSQL Tables: PostgreSQL container not running"
        fi
        
        if command -v docker >/dev/null 2>&1 && docker ps | grep -q redis; then
            echo "  Redis Keys: $(docker exec redis redis-cli DBSIZE 2>/dev/null || echo '0') keys"
        else
            echo "  Redis Keys: Redis container not running"
        fi
        
        echo ""
        echo "Spark Job Status:"
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
                echo "  Spark Master: Active with jobs"
            else
                echo "  Spark Master: Inactive"
            fi
        else
            echo "  Spark Master: curl not available"
        fi
    fi
    
    # Level 5: Performance deep dive
    if [ "$target_level" -ge 5 ]; then
        echo ""
        echo "Debug Level: Performance Deep Dive"
        echo "==================================="
        
        echo "Real-time Performance Metrics:"
        if command -v uptime >/dev/null 2>&1; then
            echo "  CPU Load: $(uptime 2>/dev/null | awk -F'load average:' '{ print $2 }' || echo 'load info unavailable')"
        else
            echo "  CPU Load: uptime command not available"
        fi
        
        if command -v free >/dev/null 2>&1; then
            echo "  Memory Usage: $(free -h 2>/dev/null | awk 'NR==2{print $3"/"$2 " (" $5 ")"}' || echo 'memory info unavailable')'"
        else
            echo "  Memory Usage: free command not available"
        fi
        
        if command -v iostat >/dev/null 2>&1; then
            echo "  Disk I/O: $(iostat -d 1 1 2>/dev/null | awk 'NR==4{print $2 " read, " $3 " write"}' || echo 'I/O stats unavailable')"
        else
            echo "  Disk I/O: iostat command not available"
        fi
        
        echo ""
        echo "Container Performance (last 5 seconds):"
        if command -v timeout >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
            timeout 5s docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "  Docker stats timeout or not available"
        else
            echo "  Container stats: timeout or docker not available"
        fi
        
        echo ""
        echo "Service Response Times:"
        if command -v timeout >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            echo "  Clinical Gateway: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:8082/actuator/health 2>/dev/null || echo 'timeout')s"
            echo "  MLflow: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:5000 2>/dev/null || echo 'timeout')s"
            echo "  MinIO: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:9000/minio/health/live 2>/dev/null || echo 'timeout')s"
        else
            echo "  Response times: timeout or curl not available"
        fi
        
        echo ""
        echo "System Load Analysis:"
        if command -v ps >/dev/null 2>&1; then
            echo "  Running Processes: $(ps aux 2>/dev/null | wc -l || echo 'process count unavailable') processes"
        else
            echo "  Running Processes: ps command not available"
        fi
        
        if command -v docker >/dev/null 2>&1; then
            echo "  Docker Containers: $(docker ps -q 2>/dev/null | wc -l || echo 'container count unavailable') running"
        else
            echo "  Docker Containers: Docker not available"
        fi
        
        if command -v systemctl >/dev/null 2>&1; then
            echo "  Active Services: $(systemctl list-units --type=service --state=running 2>/dev/null | grep -c 'loaded active' || echo '0') system services"
        else
            echo "  Active Services: systemctl not available"
        fi
    fi
    
    # Level 6: Observability monitoring
    if [ "$target_level" -ge 6 ]; then
        echo ""
        echo "Debug Level: Observability Monitoring"
        echo "====================================="
        
        echo "Monitoring Services Status:"
        
        # Prometheus
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:9090/-/healthy > /dev/null 2>&1; then
                echo "  Prometheus: Healthy"
                # Get Prometheus metrics count
                if curl -s --max-time 5 http://localhost:9090/api/v1/label/__name__/values 2>/dev/null | jq -r '.data | length' 2>/dev/null > /dev/null; then
                    echo "  Prometheus Metrics: $(curl -s --max-time 5 http://localhost:9090/api/v1/label/__name__/values 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo 'unknown') metrics"
                else
                    echo "  Prometheus Metrics: Metrics count unavailable"
                fi
            else
                echo "  Prometheus: Unhealthy (connection failed)"
            fi
        else
            echo "  Prometheus: Check skipped (curl not available)"
        fi
        
        # Grafana
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:3000/api/health > /dev/null 2>&1; then
                echo "  Grafana: Healthy"
                # Get Grafana dashboard count
                if curl -s --max-time 5 -H "Authorization: Bearer $GRAFANA_TOKEN" http://localhost:3000/api/search 2>/dev/null | jq -r 'length' 2>/dev/null > /dev/null; then
                    echo "  Grafana Dashboards: $(curl -s --max-time 5 -H "Authorization: Bearer $GRAFANA_TOKEN" http://localhost:3000/api/search 2>/dev/null | jq -r 'length' 2>/dev/null || echo 'unknown') dashboards"
                else
                    echo "  Grafana Dashboards: Dashboard count unavailable"
                fi
            else
                echo "  Grafana: Unhealthy (connection failed)"
            fi
        else
            echo "  Grafana: Check skipped (curl not available)"
        fi
        
        # OpenSearch
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:9200 > /dev/null 2>&1; then
                echo "  OpenSearch: Healthy"
                # Get OpenSearch cluster health
                if curl -s --max-time 5 http://localhost:9200/_cluster/health 2>/dev/null | jq -r '.status' 2>/dev/null > /dev/null; then
                    echo "  OpenSearch Cluster: $(curl -s --max-time 5 http://localhost:9200/_cluster/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo 'unknown') status"
                else
                    echo "  OpenSearch Cluster: Health status unavailable"
                fi
            else
                echo "  OpenSearch: Unhealthy (connection failed)"
            fi
        else
            echo "  OpenSearch: Check skipped (curl not available)"
        fi
        
        # OpenSearch Dashboards
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:5601/api/status > /dev/null 2>&1; then
                echo "  OpenSearch Dashboards: Healthy"
            else
                echo "  OpenSearch Dashboards: Unhealthy (connection failed)"
            fi
        else
            echo "  OpenSearch Dashboards: Check skipped (curl not available)"
        fi
        
        # Data Prepper
        if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 5 http://localhost:4900/health > /dev/null 2>&1; then
                echo "  Data Prepper: Healthy"
            else
                echo "  Data Prepper: Unhealthy (connection failed)"
            fi
        else
            echo "  Data Prepper: Check skipped (curl not available)"
        fi
        
        # Filebeat
        if docker ps | grep -q filebeat; then
            echo "  Filebeat: Running"
        else
            echo "  Filebeat: Not running"
        fi
        
        echo ""
        echo "Monitoring Data Flow:"
        
        # Check if monitoring services are collecting data
        if command -v curl >/dev/null 2>&1; then
            # Check Prometheus targets
            echo "  Prometheus Targets: $(curl -s --max-time 5 http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo 'unknown') active"
            
            # Check OpenSearch indices
            echo "  OpenSearch Indices: $(curl -s --max-time 5 http://localhost:9200/_cat/indices 2>/dev/null | wc -l 2>/dev/null || echo 'unknown') indices"
            
            # Check if logs are being processed
            if docker ps | grep -q filebeat; then
                echo "  Filebeat Logs: Processing logs"
            else
                echo "  Filebeat Logs: Not processing"
            fi
        else
            echo "  Monitoring Data: curl not available"
        fi
        
        echo ""
        echo "Alerting Status:"
        
        # Check Prometheus alert rules
        if command -v curl >/dev/null 2>&1; then
            echo "  Prometheus Alerts: $(curl -s --max-time 5 http://localhost:9090/api/v1/rules 2>/dev/null | jq -r '.data.groups | length' 2>/dev/null || echo 'unknown') rule groups"
            echo "  Active Alerts: $(curl -s --max-time 5 http://localhost:9090/api/v1/alerts 2>/dev/null | jq -r '.data.alerts | length' 2>/dev/null || echo 'unknown') active"
        else
            echo "  Alerting Status: curl not available"
        fi
        
        echo ""
        echo "Observability Performance:"
        
        # Check monitoring service response times
        if command -v timeout >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            echo "  Prometheus Response: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:9090/-/healthy 2>/dev/null || echo 'timeout')s"
            echo "  Grafana Response: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:3000/api/health 2>/dev/null || echo 'timeout')s"
            echo "  OpenSearch Response: $(timeout 2 curl -s -o /dev/null -w '%{time_total}s' http://localhost:9200 2>/dev/null || echo 'timeout')s"
        else
            echo "  Response Times: timeout or curl not available"
        fi
    fi
    
    echo ""
    echo "Debug commands completed"
}

export -f run_debug_commands