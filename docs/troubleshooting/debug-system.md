# Debug System Guide

## Overview

The Clinical Trials MLOps platform includes a comprehensive debug system that provides cascading levels of diagnostic information. This system is integrated with the pipeline manager and can be accessed through the `--debug-level` flag.

## Quick Start

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

# Observability monitoring
./pipeline-manager.sh --debug-level 6 --level 6
```

## Debug Levels

### Level 0: System Status
- **Purpose**: Basic system overview
- **Information Provided**:
  - Hostname and system uptime
  - Docker container status
  - Basic system identification

**Example Output**:
```
Debug Commands - Level 0
===============================
Timestamp: Mon Oct 27 10:30:45 UTC 2025
Target Level: 0

Debug Level: System Status
==========================
Hostname: clinical-trials-service
Uptime: up 2 hours, 15 minutes
[Container status output]
```

### Level 1: Service Health
- **Purpose**: Service connectivity and health status
- **Information Provided**:
  - Infrastructure services (MinIO, PostgreSQL, Redis)
  - Clinical services (Clinical Gateway, Lab Processor)
  - Processing services (Spark Master/Worker)
  - Health status (Healthy/Unhealthy)

**Example Output**:
```
Debug Level: Service Health
===========================
Infrastructure Services:
  MinIO: Healthy
  PostgreSQL: Healthy
  Redis: Healthy

Clinical Services:
  Clinical Gateway: Healthy
  Lab Processor: Healthy

Processing Services:
  Spark Master: Healthy
  Spark Worker: Healthy
```

### Level 2: Resource Monitoring
- **Purpose**: System resource utilization
- **Information Provided**:
  - Container resource usage (CPU, Memory)
  - System memory and disk usage
  - Real-time resource statistics

**Example Output**:
```
Debug Level: Resource Monitoring
=================================
Container Resource Usage:
NAME                CPU %     MEM USAGE / LIMIT     MEM %
minio-mlops         0.50%     45.2MiB / 1.94GiB    2.28%
postgres-mlflow     1.20%     120.5MiB / 1.94GiB   6.07%

System Resources:
  Memory: 1.2G/1.9G (63%)
  Disk: 4.2G/20G (21%)
```

### Level 3: Network Analysis
- **Purpose**: Network connectivity and port status
- **Information Provided**:
  - Service port status (Open/Closed)
  - Network connectivity (Internet, Docker networks)
  - Container network status

**Example Output**:
```
Debug Level: Network Analysis
=============================
Network Port Status:
  MinIO (9000): Open
  PostgreSQL (5432): Open
  Redis (6379): Open
  Kafka (9092): Open
  Clinical Gateway (8082): Open

Network Connectivity:
  Internet: Connected
  Docker Network: Active

Container Network Status:
NAMES              STATUS              PORTS
minio-mlops        Up 2 hours          0.0.0.0:9000->9000/tcp
```

### Level 4: Data Flow Analysis
- **Purpose**: Data pipeline and message flow status
- **Information Provided**:
  - Kafka topics and message queues
  - Data storage status (MinIO buckets, PostgreSQL tables, Redis keys)
  - Spark job status
  - Pipeline data flow verification

**Example Output**:
```
Debug Level: Data Flow Analysis
================================
Kafka Topics:
clinical-data
lab-results
feature-updates

Message Queue Status:
  IBM MQ: Running

Data Pipeline Status:
  MinIO Buckets: 12 buckets
  PostgreSQL Tables: 8 tables
  Redis Keys: 245 keys

Spark Job Status:
  Spark Master: Active with jobs
```

### Level 5: Performance Deep Dive
- **Purpose**: Detailed performance analysis
- **Information Provided**:
  - Real-time performance metrics
  - Container performance statistics
  - Service response times
  - System load analysis

### Level 6: Observability Monitoring
- **Purpose**: Comprehensive monitoring stack analysis
- **Information Provided**:
  - Prometheus, Grafana, OpenSearch health status
  - Monitoring service metrics and dashboard counts
  - Data flow and alerting status
  - Observability performance metrics
  - Log processing status

**Example Output**:
```
Debug Level: Performance Deep Dive
===================================
Real-time Performance Metrics:
  CPU Load: 0.15, 0.10, 0.05
  Memory Usage: 1.2G/1.9G (63%)
  Disk I/O: 0.5 read, 0.2 write

Container Performance (last 5 seconds):
NAME                CPU %     MEM USAGE     NET I/O       BLOCK I/O
minio-mlops         0.50%     45.2MiB       1.2MB/800KB   0B/0B

Service Response Times:
  Clinical Gateway: 0.045s
  MLflow: 0.023s
  MinIO: 0.015s

System Load Analysis:
  Running Processes: 156 processes
  Docker Containers: 8 running
  Active Services: 12 system services
```

## Cascading Behavior

The debug system uses cascading levels - each higher level includes all information from lower levels:

- **Level 1** includes Level 0
- **Level 2** includes Levels 0-1
- **Level 3** includes Levels 0-2
- **Level 4** includes Levels 0-3
- **Level 5** includes Levels 0-4
- **Level 6** includes Levels 0-5

## Integration with Pipeline Manager

The debug system is fully integrated with the pipeline manager and can be used with any level:

```bash
# Debug infrastructure (Level 0)
./pipeline-manager.sh --debug-level 2 --level 0

# Debug data ingestion with network analysis (Level 1)
./pipeline-manager.sh --debug-level 3 --level 1

# Debug processing with data flow analysis (Level 2)
./pipeline-manager.sh --debug-level 4 --level 2

# Debug feature engineering with performance deep dive (Level 3)
./pipeline-manager.sh --debug-level 5 --level 3

# Debug ML pipeline with service health (Level 4)
./pipeline-manager.sh --debug-level 1 --level 4

# Debug orchestration with basic status (Level 5)
./pipeline-manager.sh --debug-level 0 --level 5

# Debug observability with comprehensive monitoring (Level 6)
./pipeline-manager.sh --debug-level 6 --level 6
```

## Common Debug Scenarios

### Service Connectivity Issues
```bash
# Check if services are running and accessible
./pipeline-manager.sh --debug-level 1 --level 1
```

### Performance Problems
```bash
# Check resource usage and response times
./pipeline-manager.sh --debug-level 5 --level 4
```

### Network Problems
```bash
# Verify network connectivity and port status
./pipeline-manager.sh --debug-level 3 --level 2
```

### Data Flow Issues
```bash
# Check Kafka topics and data pipeline status
./pipeline-manager.sh --debug-level 4 --level 3
```

### System Resource Issues
```bash
# Monitor container and system resource usage
./pipeline-manager.sh --debug-level 2 --level 0
```

## Implementation Details

### File Location
- **Debug Script**: `scripts/debug-monitoring/debug-final.sh`
- **Integration**: `pipeline-manager.sh` (lines 33, 90-93, 852-857)

### Key Functions
- `run_debug_commands()` - Main debug function with cascading levels
- Integrated with pipeline manager argument parsing
- Error handling for unavailable services

### Error Handling
- Graceful degradation when services are unavailable
- Timeout protection for network checks
- Fallback messages for failed commands

## Best Practices

1. **Start Low**: Begin with Level 0 or 1 to identify basic issues
2. **Progress Up**: Move to higher levels as needed for more detail
3. **Combine with Health Checks**: Use `-h` flag with debug for comprehensive analysis
4. **Monitor Trends**: Run debug commands periodically to establish baselines
5. **Document Findings**: Use debug output to document system state during incidents

## Troubleshooting Common Issues

### "Command not found" Errors
- Ensure the debug script is executable: `chmod +x scripts/debug-monitoring/debug-final.sh`
- Verify the script path in pipeline-manager.sh

### Service Connection Failures
- Check if services are running with `docker-compose ps`
- Verify network connectivity with Level 3 debug

### Permission Issues
- Ensure Docker daemon is running
- Check user permissions for Docker commands

### Timeout Issues
- Network checks have 1-second timeouts
- Performance metrics have 2-second timeouts
- Adjust timeouts in debug script if needed

## Edge Cases and Limitations

### Known Limitations

1. **Missing Services**: The debug system gracefully handles missing services but may show incomplete information
2. **Network Timeouts**: Some network checks may timeout in high-latency environments
3. **Container Dependencies**: Some checks require specific containers to be running
4. **Command Availability**: System commands like `free`, `df`, `iostat` may not be available in all environments

### Edge Case Handling

1. **Partial Service Availability**:
   - Services that are partially available will show connection status
   - Missing services show appropriate "not available" messages

2. **Degraded Environments**:
   - Debug system works even with minimal services running
   - Fallback messages prevent script failures

3. **Network Isolation**:
   - Network checks timeout gracefully when isolated
   - Basic system status still available without network

4. **Resource Constraints**:
   - Resource-intensive checks have timeouts to prevent hangs
   - Memory and disk usage shown with available commands

## Future Enhancements

- Color-coded output for better readability
- Historical performance trend analysis
- Automated issue detection and recommendations
- Integration with monitoring dashboards
- Alert correlation capabilities