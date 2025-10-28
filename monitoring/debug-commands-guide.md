# Debug Commands & Technical Directives Guide

## Overview
This guide provides comprehensive debugging commands and technical directives for monitoring and troubleshooting the Clinical Trials Service platform.

## Quick Reference Commands

### System Health & Status
```bash
# Check all service status
docker-compose ps

# Check resource usage across all containers
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

# View detailed container information
docker-compose logs --tail=50 --follow

# Check specific service logs
docker-compose logs clinical-gateway --tail=100 --follow
docker-compose logs lab-processor --tail=100 --follow
docker-compose logs spark-master --tail=100 --follow
```

### Resource Monitoring
```bash
# Real-time resource monitoring
docker stats

# Check container resource limits
docker inspect <container_name> | grep -A 10 "HostConfig"

# Monitor system resources
htop
df -h  # Disk usage
top    # CPU/Memory usage

# Check network connections
netstat -tulpn | grep docker
```

## Service-Specific Debug Commands

### Infrastructure Services

#### Redis
```bash
# Check Redis health
docker exec redis redis-cli ping

# Monitor Redis metrics
docker exec redis redis-cli info memory
docker exec redis redis-cli info stats

# Check Redis connections
docker exec redis redis-cli info clients

# Monitor Redis keyspace
docker exec redis redis-cli info keyspace
```

#### PostgreSQL
```bash
# Check PostgreSQL connections
docker exec postgres-mlflow psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Monitor database size
docker exec postgres-mlflow psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('mlflow'));"

# Check active queries
docker exec postgres-mlflow psql -U postgres -c "SELECT pid, query_start, state, query FROM pg_stat_activity WHERE state = 'active';"

# Monitor table statistics
docker exec postgres-mlflow psql -U postgres -c "SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del FROM pg_stat_user_tables;"
```

#### Kafka
```bash
# Check Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Monitor topic details
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic clinical-data

# Check consumer groups
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Monitor consumer lag
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group lab-processor-group

# Produce test message
docker exec kafka kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic

# Consume messages
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic clinical-data --from-beginning
```

#### MinIO
```bash
# Check MinIO health
curl -s http://localhost:9000/minio/health/live

# List buckets
docker exec minio mc ls myminio/

# Monitor bucket usage
docker exec minio mc du myminio/

# Check object count
docker exec minio mc ls --recursive myminio/ | wc -l
```

### Clinical Services

#### Clinical Gateway
```bash
# Health check
curl -s http://localhost:8082/actuator/health | jq

# Check metrics
curl -s http://localhost:8082/actuator/metrics | jq

# Monitor specific metrics
curl -s http://localhost:8082/actuator/metrics/http.server.requests | jq
curl -s http://localhost:8082/actuator/metrics/jvm.memory.used | jq

# Check info endpoint
curl -s http://localhost:8082/actuator/info | jq

# Check environment
curl -s http://localhost:8082/actuator/env | jq
```

#### Lab Results Processor
```bash
# Health check
curl -s http://localhost:8083/actuator/health | jq

# Check metrics
curl -s http://localhost:8083/actuator/metrics | jq

# Monitor processing metrics
curl -s http://localhost:8083/actuator/metrics/kafka.consumer.records.consumed.total | jq

# Check MQ connection
curl -s http://localhost:8083/actuator/health | jq '.components.mq'
```

#### IBM MQ
```bash
# Check queue manager status
docker exec clinical-mq dspmq

# Monitor queue depths
docker exec clinical-mq runmqsc CLINICAL_QM << EOF
display qstatus('CLINICAL.DATA.IN')
display qstatus('LAB.RESULTS.OUT')
EOF

# Check channel status
docker exec clinical-mq runmqsc CLINICAL_QM << EOF
display chstatus('DEV.APP.SVRCONN')
EOF

# Monitor message flow
docker exec clinical-mq runmqsc CLINICAL_QM << EOF
display qstatus('*') ALL
EOF
```

### Spark Services

#### Spark Master
```bash
# Check Spark UI
curl -s http://localhost:8080 | head -20

# Monitor Spark applications
docker exec spark-master curl -s http://localhost:8080/api/v1/applications | jq

# Check worker status
docker exec spark-master curl -s http://localhost:8080/api/v1/workers | jq
```

#### Spark Worker
```bash
# Check worker metrics
docker exec spark-worker curl -s http://localhost:8081/metrics/json/ | jq

# Monitor executor status
docker exec spark-worker curl -s http://localhost:8081/api/v1/applications | jq
```

### Monitoring Services

#### Prometheus
```bash
# Check Prometheus health
curl -s http://localhost:9090/-/healthy

# Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq

# Check targets
curl -s 'http://localhost:9090/api/v1/targets' | jq

# Monitor scrape health
curl -s 'http://localhost:9090/api/v1/query?query=up{job="clinical-services"}' | jq
```

#### Grafana
```bash
# Check Grafana health
curl -s http://localhost:3000/api/health | jq

# List dashboards
curl -s -u admin:admin http://localhost:3000/api/search | jq

# Check datasources
curl -s -u admin:admin http://localhost:3000/api/datasources | jq
```

## Performance Monitoring Commands

### CPU & Memory Analysis
```bash
# Monitor container CPU usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check container memory details
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

# Monitor system memory
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Check CPU utilization
mpstat 1 5
```

### Disk I/O Monitoring
```bash
# Monitor disk usage
df -h

# Check I/O statistics
iostat -x 1 5

# Monitor container disk usage
docker system df
```

### Network Monitoring
```bash
# Check network interfaces
ip addr show

# Monitor network traffic
iftop

# Check port usage
netstat -tulpn | grep LISTEN

# Monitor container network
docker network ls
docker network inspect clinical-trials-service_mlops-network
```

## Troubleshooting Commands

### Service Restart & Recovery
```bash
# Restart specific service
docker-compose restart clinical-gateway

# Restart with resource limits
docker-compose --compatibility up -d clinical-gateway

# Force recreate service
docker-compose up -d --force-recreate clinical-gateway

# Scale services
docker-compose up -d --scale spark-worker=2
```

### Log Analysis
```bash
# Search for errors in logs
docker-compose logs | grep -i error
docker-compose logs | grep -i exception

# Monitor real-time logs
docker-compose logs -f

# Check specific time range
docker-compose logs --since "2024-01-01T00:00:00" --until "2024-01-01T23:59:59"

# Export logs to file
docker-compose logs > service_logs_$(date +%Y%m%d_%H%M%S).log
```

### Container Inspection
```bash
# Inspect container configuration
docker inspect clinical-gateway

# Check container environment variables
docker exec clinical-gateway env

# Monitor container processes
docker top clinical-gateway

# Check container resource limits
docker inspect clinical-gateway | jq '.[0].HostConfig'
```

## Alerting & Notification Commands

### Resource Threshold Monitoring
```bash
# Check for high memory usage
docker stats --no-stream --format "table {{.Name}}\t{{.MemPerc}}" | awk '$2 > 80'

# Monitor CPU spikes
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | awk '$2 > 90'

# Check disk space alerts
df -h | awk '$5 > 80'
```

### Service Health Alerts
```bash
# Check service health status
docker-compose ps | grep -v "Up (healthy)"

# Monitor HTTP endpoints
curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/actuator/health

# Check database connectivity
docker exec postgres-mlflow pg_isready
```

## Data Flow Debugging

### Message Queue Debugging
```bash
# Check MQ message flow
docker exec clinical-mq runmqsc CLINICAL_QM << 'EOF'
display qlocal('CLINICAL.DATA.IN') curdepth
display qlocal('LAB.RESULTS.OUT') curdepth
EOF

# Monitor Kafka message flow
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic clinical-data --time -1
```

### Data Pipeline Monitoring
```bash
# Check Spark streaming jobs
docker exec spark-master curl -s http://localhost:8080/api/v1/applications | jq '.[] | select(.name | contains("streaming"))'

# Monitor ML pipeline status
docker exec mlflow-server curl -s http://localhost:5000/api/2.0/mlflow/experiments/list | jq
```

## Security & Access Commands

### Access Control
```bash
# Check service authentication
curl -s -u user:password http://localhost:8082/actuator/health

# Monitor security events
docker-compose logs | grep -i "authentication\|authorization\|security"
```

### Certificate & SSL
```bash
# Check SSL certificates
openssl s_client -connect localhost:9443 -showcerts

# Verify certificate validity
openssl x509 -in certificate.crt -text -noout
```

## Backup & Recovery Commands

### Data Backup
```bash
# Backup PostgreSQL databases
docker exec postgres-mlflow pg_dump -U postgres mlflow > mlflow_backup_$(date +%Y%m%d).sql

# Backup MinIO data
docker exec minio mc mirror myminio/ /backup/

# Export configuration
docker-compose config > docker-compose-backup-$(date +%Y%m%d).yml
```

### Data Recovery
```bash
# Restore PostgreSQL database
docker exec -i postgres-mlflow psql -U postgres mlflow < backup_file.sql

# Restore MinIO data
docker exec minio mc mirror /backup/ myminio/
```

## Automation Scripts

### Health Check Script
```bash
#!/bin/bash
# health-check.sh

SERVICES=("clinical-gateway" "lab-processor" "spark-master" "postgres-mlflow" "redis")

for service in "${SERVICES[@]}"; do
    if docker-compose ps | grep -q "${service}.*Up"; then
        echo "✅ ${service}: RUNNING"
    else
        echo "❌ ${service}: DOWN"
    fi
done

# Check resource usage
echo "\n📊 Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

### Performance Monitoring Script
```bash
#!/bin/bash
# performance-monitor.sh

while true; do
    clear
    echo "🚀 Performance Monitor - $(date)"
    echo "================================"
    
    # Container stats
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    # System resources
    echo -e "\n💻 System Resources:"
    echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2}')"
    echo "Disk: $(df -h / | awk 'NR==2{print $5}')"
    
    sleep 5
done
```

## Emergency Procedures

### Service Recovery
```bash
# Emergency restart all services
docker-compose down && docker-compose --compatibility up -d

# Reset specific service
docker-compose stop clinical-gateway
docker-compose rm -f clinical-gateway
docker-compose --compatibility up -d clinical-gateway

# Clear problematic containers
docker system prune -f
docker volume prune -f
```

### Data Recovery
```bash
# Rebuild from source
docker-compose down
docker-compose build --no-cache
docker-compose --compatibility up -d

# Restore from backup
./scripts/backup/restore-backup.sh
```

## Best Practices

### Regular Monitoring
- Run health checks every 15 minutes
- Monitor resource usage hourly
- Check logs daily for errors
- Review performance metrics weekly

### Alert Thresholds
- CPU: Alert at 80%, Critical at 95%
- Memory: Alert at 75%, Critical at 90%
- Disk: Alert at 80%, Critical at 95%
- Service Health: Immediate alert on failure

### Maintenance Windows
- Schedule maintenance during low-traffic periods
- Perform backups before major changes
- Test recovery procedures quarterly

---

**Last Updated**: $(date)
**Version**: 1.0
**Maintainer**: Platform Engineering Team