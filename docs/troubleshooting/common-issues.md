# Common Issues and Solutions

## Quick Debug Commands

For comprehensive troubleshooting, use the integrated debug system:

```bash
# Basic system status
./pipeline-manager.sh --debug-level 0 --level 0

# Service health checks
./pipeline-manager.sh --debug-level 1 --level 1

# Full system analysis
./pipeline-manager.sh --debug-level 5 --level 5
```

See [Debug System Guide](./debug-system.md) for detailed information.

## Infrastructure Issues (Level 0)

### MinIO Not Accessible
**Symptoms**:
- Cannot connect to MinIO on port 9000
- File uploads/downloads fail
- MLflow cannot access artifact storage

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 1 --level 0
```

**Solutions**:
1. Check if MinIO container is running: `docker-compose ps minio-mlops`
2. Verify MinIO health: `curl http://localhost:9000/minio/health/live`
3. Check MinIO logs: `docker-compose logs minio-mlops`

### PostgreSQL Connection Issues
**Symptoms**:
- MLflow cannot connect to tracking database
- Database migrations fail
- Connection timeout errors

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 3 --level 0
```

**Solutions**:
1. Verify PostgreSQL is running: `docker exec postgres-mlflow pg_isready -U postgres`
2. Check database connectivity: `docker exec postgres-mlflow psql -U postgres -d mlflow_db -c 'SELECT 1;'`
3. Examine PostgreSQL logs: `docker-compose logs postgres-mlflow`

### Redis Connection Problems
**Symptoms**:
- Feature store caching failures
- Session storage issues
- Cache miss errors

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 1 --level 0
```

**Solutions**:
1. Test Redis connectivity: `docker exec redis redis-cli ping`
2. Check Redis memory usage: `docker exec redis redis-cli info memory`
3. View Redis logs: `docker-compose logs redis`

## Data Ingestion Issues (Level 1)

### Kafka Topics Not Created
**Symptoms**:
- No messages flowing through pipeline
- Producer/consumer connection errors
- Topic not found errors

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 4 --level 1
```

**Solutions**:
1. List Kafka topics: `docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092`
2. Check Kafka logs: `docker-compose logs kafka`
3. Verify Zookeeper: `docker-compose logs zookeeper`

### Clinical Gateway Not Responding
**Symptoms**:
- HTTP 503 errors from gateway
- Health check failures
- API endpoints unavailable

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 1 --level 1
```

**Solutions**:
1. Check gateway health: `curl http://localhost:8082/actuator/health`
2. Verify gateway logs: `docker-compose logs clinical-data-gateway`
3. Check resource limits: `docker stats clinical-data-gateway`

## Data Processing Issues (Level 2)

### Spark Jobs Failing
**Symptoms**:
- Spark applications not starting
- Job submission errors
- Executor failures

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 4 --level 2
```

**Solutions**:
1. Check Spark UI: http://localhost:8080
2. View Spark logs: `docker-compose logs spark-master spark-worker`
3. Verify resource allocation: `docker stats spark-master spark-worker`

### Streaming Pipeline Stalled
**Symptoms**:
- No new data processed
- Lagging consumer groups
- Processing delays

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 4 --level 2
```

**Solutions**:
1. Check Kafka consumer groups: `docker exec kafka kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list`
2. Monitor Spark streaming metrics
3. Check network connectivity between services

## Feature Engineering Issues (Level 3)

### Feature Store Synchronization
**Symptoms**:
- Offline/online feature mismatch
- Stale feature data
- Redis cache inconsistencies

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 4 --level 3
```

**Solutions**:
1. Compare feature stores: `./pipeline-manager.sh --compare-stores --level 3`
2. Check feature pipeline logs
3. Verify MinIO bucket contents

### Feature Volume Problems
**Symptoms**:
- Feature engineering container restarts
- Volume mount failures
- Permission denied errors

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 2 --level 3
```

**Solutions**:
1. Inspect feature volume: `./pipeline-manager.sh --inspect-feature-volume --level 3`
2. Check Docker volume status: `docker volume ls`
3. Verify volume permissions

## ML Pipeline Issues (Level 4)

### MLflow Tracking Problems
**Symptoms**:
- Experiments not logging
- Artifact storage failures
- Database connection errors

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 4 --level 4
```

**Solutions**:
1. Check MLflow UI: http://localhost:5000
2. Verify PostgreSQL connection
3. Check MinIO artifact storage

### Model Serving Failures
**Symptoms**:
- Model prediction errors
- Service unavailable
- Inference timeouts

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 5 --level 4
```

**Solutions**:
1. Test model serving endpoint: `curl http://localhost:8000/health`
2. Check model serving logs: `docker-compose logs model-serving`
3. Verify model file availability

## Orchestration Issues (Level 5)

### Airflow DAG Failures
**Symptoms**:
- DAGs not running
- Task failures
- Scheduler issues

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 1 --level 5
```

**Solutions**:
1. Check Airflow UI: http://localhost:8085
2. View Airflow logs: `docker-compose logs airflow-webserver airflow-scheduler`
3. Verify DAG file locations

## Performance Issues

### High Resource Usage
**Symptoms**:
- Slow response times
- Container restarts
- Memory/CPU exhaustion

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 5 --level 0
```

**Solutions**:
1. Monitor resource usage: `docker stats`
2. Check system resources: `free -h && df -h`
3. Identify resource-intensive containers

### Network Latency
**Symptoms**:
- Slow inter-service communication
- Connection timeouts
- High network I/O

**Debug Commands**:
```bash
./pipeline-manager.sh --debug-level 3 --level 0
```

**Solutions**:
1. Check network connectivity between containers
2. Monitor network usage: `docker stats --format "table {{.Name}}\t{{.NetIO}}"`
3. Verify Docker network configuration

## General Troubleshooting Steps

1. **Start with Basic Debug**: Always begin with Level 0 or 1 debug
2. **Check Logs**: Use `-l` flag to view service logs
3. **Verify Health**: Run health checks with `-h` flag
4. **Monitor Resources**: Use Level 2 debug for resource monitoring
5. **Analyze Network**: Use Level 3 debug for connectivity issues
6. **Inspect Data Flow**: Use Level 4 debug for pipeline issues
7. **Deep Performance**: Use Level 5 debug for detailed analysis

## Emergency Recovery

### Complete System Reset
```bash
# Stop all services and remove data
./pipeline-manager.sh --clean --level 5

# Restart from scratch
./pipeline-manager.sh --start --level 5
```

### Service-Specific Reset
```bash
# Reset specific level
./pipeline-manager.sh --restart-rebuild --level 3

# With health checks
./pipeline-manager.sh --restart-rebuild -h --level 3
```

## Getting Help

- Use the debug system to gather comprehensive system state
- Document debug output when reporting issues
- Check service-specific documentation
- Review architecture diagrams for system understanding