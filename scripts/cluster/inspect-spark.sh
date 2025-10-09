#!/bin/bash
# ===============================================================
# ⚡ Comprehensive Apache Spark Cluster Inspection Script
# Author: Arsene AI Assistant
# ===============================================================

set -e

# ---------- COLORS ----------
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

MASTER_CONTAINER="spark-master"
WORKER_CONTAINER="spark-worker"
STREAMING_CONTAINER="spark-streaming"
BATCH_CONTAINER="spark-batch"
MASTER_UI="http://localhost:8080"
WORKER_UI="http://localhost:8081"

# ---------- 1. CLUSTER STATUS ----------
print_header "1. Spark Master & Worker Health Check"

docker ps --filter "name=spark" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "spark-master|spark-worker"

echo ""
if curl -s --head "$MASTER_UI" | grep -q "200 OK"; then
    echo -e "${GREEN}✅ Spark Master UI reachable at $MASTER_UI${NC}"
else
    echo -e "${RED}❌ Spark Master UI not reachable on $MASTER_UI${NC}"
fi

if curl -s --head "$WORKER_UI" | grep -q "200 OK"; then
    echo -e "${GREEN}✅ Spark Worker UI reachable at $WORKER_UI${NC}"
else
    echo -e "${RED}❌ Spark Worker UI not reachable on $WORKER_UI${NC}"
fi

# ---------- 2. MASTER INFO ----------
print_header "2. Spark Master Cluster Info"
docker exec $MASTER_CONTAINER /opt/spark/bin/spark-class org.apache.spark.deploy.Client kill 2>/dev/null || true
docker exec $MASTER_CONTAINER curl -s http://localhost:8080/json/ | jq '.activeapps, .workers' || echo -e "${YELLOW}⚠️  Could not parse JSON (jq missing?).${NC}"

# ---------- 3. WORKER STATUS ----------
print_header "3. Spark Worker Node Summary"
docker exec $WORKER_CONTAINER curl -s http://localhost:8081/json/ | jq '.id, .cores, .memory, .executors' || echo -e "${YELLOW}⚠️  Could not fetch worker metrics.${NC}"

# ---------- 4. ACTIVE APPLICATIONS ----------
print_header "4. Active Applications in Spark Master"
docker exec $MASTER_CONTAINER curl -s http://localhost:8080/json/ | jq '.activeapps' || echo -e "${YELLOW}⚠️ No active apps found.${NC}"

# ---------- 5. STREAMING JOBS ----------
print_header "5. Spark Streaming Job Logs & Status"
if docker ps | grep -q $STREAMING_CONTAINER; then
    echo -e "${YELLOW}🔹 Streaming container logs (last 15 lines):${NC}"
    docker logs --tail 15 $STREAMING_CONTAINER
else
    echo -e "${RED}⚠️ Streaming container not running.${NC}"
fi

# ---------- 6. BATCH JOBS ----------
print_header "6. Spark Batch Job Logs & Status"
if docker ps | grep -q $BATCH_CONTAINER; then
    echo -e "${YELLOW}🔹 Batch container logs (last 15 lines):${NC}"
    docker logs --tail 15 $BATCH_CONTAINER
else
    echo -e "${YELLOW}ℹ️ Batch job container not running (likely profile=batch-job).${NC}"
fi

# ---------- 7. CONNECTIVITY TEST ----------
print_header "7. Worker → Master Connectivity Test"

if docker exec $WORKER_CONTAINER bash -c "curl -s http://spark-master:8080 >/dev/null"; then
    echo -e "${GREEN}✅ Worker can reach Spark Master UI on port 8080 (network OK).${NC}"
else
    echo -e "${RED}❌ Worker cannot reach Spark Master — check mlops-network.${NC}"
fi



# ---------- 8. ENVIRONMENT SUMMARY ----------
print_header "8. Environment Summary"
echo -e "${GREEN}Spark Master:${NC} $MASTER_CONTAINER (UI: $MASTER_UI)"
echo -e "${GREEN}Spark Worker:${NC} $WORKER_CONTAINER (UI: $WORKER_UI)"
echo -e "${GREEN}Streaming Job:${NC} $STREAMING_CONTAINER"
echo -e "${GREEN}Batch Job:${NC} $BATCH_CONTAINER"
echo ""
echo -e "${BLUE}To submit a manual job, run:${NC}"
echo -e "${GREEN}docker exec -it spark-master /opt/spark/bin/spark-submit --master spark://spark-master:7077 your_script.py${NC}"
echo ""

# ---------- 9. OPTIONAL: EXECUTOR DETAIL ----------
print_header "9. Executor & Resource Summary"
docker exec $MASTER_CONTAINER curl -s http://localhost:8080/json/ | jq '.workers[] | {host: .host, cores: .cores, mem: .memory}' || echo -e "${YELLOW}⚠️ No worker info available.${NC}"

# ---------- 10. SUMMARY ----------
print_header "✅ Spark Cluster Inspection Complete!"
echo -e "${GREEN}✔️ Checked master, workers, streaming, and batch jobs.${NC}"
echo -e "${GREEN}✔️ Validated connectivity and UI endpoints.${NC}"
echo -e "${GREEN}✔️ Logs for running Spark apps displayed.${NC}"
echo ""
