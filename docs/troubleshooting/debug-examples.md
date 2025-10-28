# Debug System Usage Examples

## Quick Reference

```bash
# Basic system status
./pipeline-manager.sh --debug-level 0 --level 0

# Service health checks
./pipeline-manager.sh --debug-level 1 --level 1

# Resource monitoring
./pipeline-manager.sh --debug-level 2 --level 2

# Network analysis
./pipeline-manager.sh --debug-level 3 --level 3

# Data flow analysis
./pipeline-manager.sh --debug-level 4 --level 4

# Performance deep dive
./pipeline-manager.sh --debug-level 5 --level 5
```

## Level-Specific Examples

### Infrastructure (Level 0)

**Basic System Status**
```bash
./pipeline-manager.sh --debug-level 0 --level 0
```
*Output: Hostname, uptime, container status*

**Resource Monitoring**
```bash
./pipeline-manager.sh --debug-level 2 --level 0
```
*Output: Container resource usage, system memory, disk usage*

**Network Analysis**
```bash
./pipeline-manager.sh --debug-level 3 --level 0
```
*Output: Port status, network connectivity, container networking*

### Data Ingestion (Level 1)

**Service Health**
```bash
./pipeline-manager.sh --debug-level 1 --level 1
```
*Output: Infrastructure, clinical, and processing service health*

**Data Flow Analysis**
```bash
./pipeline-manager.sh --debug-level 4 --level 1
```
*Output: Kafka topics, message queues, data pipeline status*

**Performance Analysis**
```bash
./pipeline-manager.sh --debug-level 5 --level 1
```
*Output: Response times, resource usage, system load*

### Data Processing (Level 2)

**Resource Monitoring**
```bash
./pipeline-manager.sh --debug-level 2 --level 2
```
*Output: Spark container resources, system resource usage*

**Network Analysis**
```bash
./pipeline-manager.sh --debug-level 3 --level 2
```
*Output: Spark ports, network connectivity*

**Data Flow Analysis**
```bash
./pipeline-manager.sh --debug-level 4 --level 2
```
*Output: Spark job status, data pipeline verification*

### Feature Engineering (Level 3)

**Service Health**
```bash
./pipeline-manager.sh --debug-level 1 --level 3
```
*Output: Feature engineering service health*

**Data Flow Analysis**
```bash
./pipeline-manager.sh --debug-level 4 --level 3
```
*Output: Feature store status, data synchronization*

**Performance Deep Dive**
```bash
./pipeline-manager.sh --debug-level 5 --level 3
```
*Output: Feature processing performance, response times*

### ML Pipeline (Level 4)

**Basic Status**
```bash
./pipeline-manager.sh --debug-level 0 --level 4
```
*Output: MLflow and model serving container status*

**Service Health**
```bash
./pipeline-manager.sh --debug-level 1 --level 4
```
*Output: MLflow tracking, model serving health*

**Performance Analysis**
```bash
./pipeline-manager.sh --debug-level 5 --level 4
```
*Output: Model inference times, resource usage*

### Orchestration (Level 5)

**System Status**
```bash
./pipeline-manager.sh --debug-level 0 --level 5
```
*Output: Airflow container status*

**Service Health**
```bash
./pipeline-manager.sh --debug-level 1 --level 5
```
*Output: Airflow webserver and scheduler health*

**Resource Monitoring**
```bash
./pipeline-manager.sh --debug-level 2 --level 5
```
*Output: Airflow container resource usage*

## Common Troubleshooting Scenarios

### Service Connectivity Issues

**Symptoms**: Services not responding, connection timeouts

```bash
# Check all service health
./pipeline-manager.sh --debug-level 1 --level 5

# Verify network connectivity
./pipeline-manager.sh --debug-level 3 --level 0

# Check resource availability
./pipeline-manager.sh --debug-level 2 --level 0
```

### Performance Problems

**Symptoms**: Slow response times, high resource usage

```bash
# Check system resources
./pipeline-manager.sh --debug-level 2 --level 0

# Analyze performance metrics
./pipeline-manager.sh --debug-level 5 --level 4

# Monitor container performance
./pipeline-manager.sh --debug-level 5 --level 2
```

### Data Flow Issues

**Symptoms**: No data processing, pipeline stalls

```bash
# Check Kafka topics and queues
./pipeline-manager.sh --debug-level 4 --level 1

# Verify Spark job status
./pipeline-manager.sh --debug-level 4 --level 2

# Check feature store synchronization
./pipeline-manager.sh --debug-level 4 --level 3
```

### Network Problems

**Symptoms**: Connection failures, port unreachable

```bash
# Check all service ports
./pipeline-manager.sh --debug-level 3 --level 0

# Verify network connectivity
./pipeline-manager.sh --debug-level 3 --level 5

# Check container networking
./pipeline-manager.sh --debug-level 3 --level 2
```

### Resource Exhaustion

**Symptoms**: Container restarts, memory errors

```bash
# Monitor resource usage
./pipeline-manager.sh --debug-level 2 --level 0

# Check system load
./pipeline-manager.sh --debug-level 5 --level 0

# Identify resource-intensive containers
./pipeline-manager.sh --debug-level 5 --level 4
```

## Advanced Debug Combinations

### Complete System Analysis
```bash
# Full system health check
./pipeline-manager.sh --debug-level 5 --level 5

# With health checks
./pipeline-manager.sh --debug-level 5 -h --level 5

# With logs and visualization
./pipeline-manager.sh --debug-level 5 -vhl --level 5
```

### Targeted Debug Sessions

**Infrastructure Focus**
```bash
./pipeline-manager.sh --debug-level 3 -vh --level 0
```

**Data Pipeline Focus**
```bash
./pipeline-manager.sh --debug-level 4 -vh --level 2
```

**ML Pipeline Focus**
```bash
./pipeline-manager.sh --debug-level 5 -vh --level 4
```

**Orchestration Focus**
```bash
./pipeline-manager.sh --debug-level 2 -vh --level 5
```

## Debug Output Interpretation

### Healthy System Indicators
- All services show "Healthy" status
- Ports show "Open" status
- Resource usage below 80%
- Response times under 1 second
- No error messages in debug output

### Warning Indicators
- Some services show "Unhealthy"
- Ports show "Closed" status
- Resource usage above 80%
- Response times over 2 seconds
- Some commands fail with fallback messages

### Critical Indicators
- Multiple services "Unhealthy"
- Multiple ports "Closed"
- Resource usage at 100%
- Response timeouts
- Command failures without fallbacks

## Best Practices

1. **Start Simple**: Begin with Level 0 or 1 debug
2. **Progress Methodically**: Move to higher levels as needed
3. **Document Findings**: Save debug output for comparison
4. **Establish Baselines**: Run debug commands when system is healthy
5. **Monitor Trends**: Run periodic debug sessions
6. **Combine Tools**: Use debug with health checks and logs

## Integration with Other Tools

### With Health Checks
```bash
./pipeline-manager.sh --debug-level 3 -h --level 2
```

### With Logs
```bash
./pipeline-manager.sh --debug-level 2 -l --level 3
```

### With Visualization
```bash
./pipeline-manager.sh --debug-level 4 -v --level 4
```

### Complete Monitoring Session
```bash
./pipeline-manager.sh --debug-level 5 -vhls --level 5
```

## Automation Examples

### Scheduled Debug Sessions
```bash
# Daily system check
0 8 * * * /workspaces/clinical-trials-service/pipeline-manager.sh --debug-level 2 --level 0

# Weekly performance analysis
0 9 * * 1 /workspaces/clinical-trials-service/pipeline-manager.sh --debug-level 5 --level 5
```

### Alert Integration
```bash
# Check specific service and alert if unhealthy
if ! ./pipeline-manager.sh --debug-level 1 --level 1 | grep -q "Healthy"; then
    echo "ALERT: Service health issues detected"
    # Send alert notification
fi
```

### Performance Monitoring
```bash
# Monitor response times and alert if slow
response_time=$(./pipeline-manager.sh --debug-level 5 --level 4 | grep "Clinical Gateway" | awk '{print $3}' | sed 's/s//')
if (( $(echo "$response_time > 2.0" | bc -l) )); then
    echo "ALERT: High response time detected: ${response_time}s"
fi
```