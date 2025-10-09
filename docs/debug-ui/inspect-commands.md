You're right! The `--format` flag doesn't exist for `docker compose`. Let me give you the correct commands to inspect your Docker Compose services.

---

## 🔍 **Correct Docker Compose Inspection Commands**

### **1. List All Services**

```bash
docker compose ps
```

**Better formatted view:**
```bash
docker compose ps --format table
```

---

### **2. List Running Containers with Images**

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

**Example output:**
```
NAMES                    IMAGE                                          STATUS              PORTS
kafka-producer           clinical-kafka-producer                        Up 5 minutes        
kafka-consumer           clinical-kafka-consumer                        Up 5 minutes        
kafka                    confluentinc/cp-kafka:7.5.0                   Up 5 minutes        0.0.0.0:9092->9092/tcp
kafka-ui                 provectuslabs/kafka-ui:latest                  Up 5 minutes        0.0.0.0:8090->8080/tcp
minio                    minio/minio:latest                             Up 5 minutes        0.0.0.0:9000-9001->9000-9001/tcp
spark-master             apache/spark:3.5.4-java17                      Up 5 minutes        0.0.0.0:7077->7077/tcp, 0.0.0.0:8080->8080/tcp
```

---

### **3. Show Only Running Containers**

```bash
docker ps
```

---

### **4. Show All Containers (including stopped)**

```bash
docker ps -a
```

---

### **5. Filter by Specific Project**

```bash
# Show only containers from this docker compose project
docker ps --filter "label=com.docker.compose.project=clinical-trials-service"
```

---

### **6. Get Detailed Service Info**

```bash
docker compose config --services
```

**Output:**
```
minio
minio-setup
zookeeper
kafka
clinical-mq
postgres-mlflow
postgres-airflow
redis
mlflow-server
kafka-producer
kafka-consumer
kafka-ui
...
```

---

### **7. Inspect Specific Service Configuration**

```bash
# View full configuration for kafka-producer
docker compose config kafka-producer
```

---

### **8. Show Service Dependencies**

```bash
docker compose config | grep -A 5 "depends_on:"
```

---

### **9. Get Container IDs and Images**

```bash
docker compose ps -q | xargs docker inspect --format='{{.Name}} - {{.Config.Image}}'
```

---

### **10. Custom Formatted Output (All Running Containers)**

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(kafka|minio|spark|mlflow|prometheus|grafana|opensearch)"
```

---

## 🎯 **Quick Reference Commands**

```bash
# View all services and their status
docker compose ps

# View logs for specific service
docker compose logs -f kafka-producer

# View logs for multiple services
docker compose logs -f kafka-producer kafka-consumer

# Restart a service
docker compose restart kafka-producer

# Stop a service
docker compose stop kafka-producer

# Start a service
docker compose start kafka-producer

# Remove and recreate a service
docker compose up -d --force-recreate kafka-producer

# View resource usage
docker stats

# Execute command in container
docker exec -it kafka bash

# View container details
docker inspect kafka

# View service configuration
docker compose config kafka-producer
```



---

## 🚀 **Quick Start Commands (Updated)**

```bash
# Start all core services
docker compose up -d

# Check status
docker compose ps

# View specific logs
docker compose logs -f kafka-producer kafka-consumer

# Open UIs (macOS)
open http://localhost:8090  # Kafka UI
open http://localhost:9001  # MinIO Console

# Open UIs (Linux)
xdg-open http://localhost:8090
xdg-open http://localhost:9001

# Stop everything
docker compose down

# Full cleanup (removes volumes)
docker compose down -v
```

---

## 🔍 **Find Your Docker Compose Project Label**

### **Method 1: Inspect Any Running Container**

```bash
# Pick any container from your compose stack
docker inspect kafka | grep com.docker.compose.project
```

**Or more readable:**
```bash
docker inspect kafka --format='{{index .Config.Labels "com.docker.compose.project"}}'
```

---

### **Method 2: List All Project Labels**

```bash
# Show all unique project labels
docker ps -a --format '{{.Label "com.docker.compose.project"}}' | sort -u
```

---

### **Method 3: Check from docker compose.yml Directory**

```bash
# Docker Compose uses the directory name as default project name
basename $(pwd)
```

**Or explicitly check:**
```bash
docker compose ps --format json | jq -r '.[0].Labels."com.docker.compose.project"' | head -1
```

---

### **Method 4: Show All Labels for a Container**

```bash
# See ALL labels
docker inspect kafka --format='{{json .Config.Labels}}' | jq
```

**Expected output:**
```json
{
  "com.docker.compose.project": "clinical-trials-service",
  "com.docker.compose.project.config_files": "/workspaces/clinical-trials-service/docker compose.yml",
  "com.docker.compose.project.working_dir": "/workspaces/clinical-trials-service",
  "com.docker.compose.service": "kafka",
  "com.docker.compose.version": "2.23.0"
}
```

---

## 🎯 **Your Correct Filter Command**

Based on your directory structure, your project name is likely `clinical-trials-service`:

```bash
# List containers from your project
docker ps --filter "label=com.docker.compose.project=clinical-trials-service"
```

**Or use a wildcard approach:**
```bash
# Find the project name first
PROJECT_NAME=$(docker inspect kafka --format='{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)

# Then use it
docker ps --filter "label=com.docker.compose.project=$PROJECT_NAME"
```

---


## 🔧 **Override Project Name**

If you want to set a specific project name:

### **Option 1: Use `-p` flag**
```bash
docker compose -p clinical-mlops up -d
```

### **Option 2: Set environment variable**
```bash
export COMPOSE_PROJECT_NAME=clinical-mlops
docker compose up -d
```

### **Option 3: Add to .env file**
```bash
echo "COMPOSE_PROJECT_NAME=clinical-mlops" >> .env
docker compose up -d
```

---

## 📋 **Useful Filter Commands**

```bash
# Find your project name
PROJECT_NAME=$(docker inspect kafka --format='{{index .Config.Labels "com.docker.compose.project"}}')

# List all containers in project
docker ps --filter "label=com.docker.compose.project=$PROJECT_NAME"

# List specific service
docker ps --filter "label=com.docker.compose.service=kafka-producer"

# List by project AND service
docker ps \
  --filter "label=com.docker.compose.project=$PROJECT_NAME" \
  --filter "label=com.docker.compose.service=kafka-producer"

# Get IDs only
docker ps -q --filter "label=com.docker.compose.project=$PROJECT_NAME"

# Stop all containers in project
docker ps -q --filter "label=com.docker.compose.project=$PROJECT_NAME" | xargs docker stop

# View logs for all project containers
docker ps -q --filter "label=com.docker.compose.project=$PROJECT_NAME" | xargs docker logs -f

# Show resource usage for project
docker stats $(docker ps -q --filter "label=com.docker.compose.project=$PROJECT_NAME")
```

---

## 🎯 **Quick One-Liner to Get Your Project Name**

```bash
# Auto-detect and export
export PROJECT_NAME=$(docker ps -q | head -1 | xargs docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}')
echo "Your project name: $PROJECT_NAME"

# Now use it
docker ps --filter "label=com.docker.compose.project=$PROJECT_NAME"
```

---

## ✅ **Verification**

```bash
# Check current project
docker ps --format '{{.Label "com.docker.compose.project"}}' | head -1

# Should output something like:
# clinical-trials-service
```

---

**Now you know exactly how to find and use your Docker Compose project label!** 🎉