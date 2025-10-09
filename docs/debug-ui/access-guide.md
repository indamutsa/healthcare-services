# 🎯 Complete UI Access Guide for Clinical MLOps Platform

Here's your consolidated guide with all UIs, verification steps, and CLI commands for inspecting your entire data pipeline.

---

## 📊 **Quick Access Dashboard**

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Kafka UI** | http://localhost:8090 | - | Browse topics, messages, consumer groups |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin | Browse data lake (bronze/silver layers) |
| **Spark Master UI** | http://localhost:8080 | - | Monitor Spark jobs and workers |
| **Spark Worker UI** | http://localhost:8081 | - | Worker metrics and tasks |
| **MLflow UI** | http://localhost:5000 | - | Track ML experiments |
| **Prometheus** | http://localhost:9090 | - | Query metrics |
| **Grafana** | http://localhost:3000 | admin / admin | View dashboards |
| **OpenSearch Dashboards** | http://localhost:5601 | - | Search logs |
| **Airflow** | http://localhost:8081 | admin / admin | DAG management (if enabled) |
| **Clinical Gateway** | http://localhost:8082/actuator/health | - | Health check |
| **Lab Processor** | http://localhost:8083/actuator/health | - | Health check |
| **IBM MQ Console** | https://localhost:9443 | admin / admin123 | Queue manager |

---

## 🔥 **Updated docker compose.yml** (Add Kafka UI)

## 🚀 **Start Everything**

```bash
# Start core infrastructure
docker compose up -d

# Check all services are running
docker compose ps

# View logs
docker compose logs -f kafka-producer kafka-consumer
```

---

## 📋 **Kafka Verification Checklist**

### **1. Using Kafka UI (Easiest) 🌐**

Open **http://localhost:8090**

**What you can do:**
- ✅ View all topics
- ✅ See topic configurations (partitions, replication factor)
- ✅ Browse messages in real-time
- ✅ View consumer groups and lag
- ✅ Monitor broker health

**Steps:**
1. Click **Topics** → See all 4 topics
2. Click on **patient-vitals** → View messages
3. Click **Consumers** → See `clinical-consumer-group`
4. Click **Brokers** → See broker status

---

### **2. Using CLI (Advanced) 🖥️**

#### **A. Enter Kafka Container**

```bash
# Enter container
docker exec -it kafka bash

# Set helper variable
export BS=localhost:9092
```

#### **B. List All Topics**

```bash
kafka-topics --bootstrap-server $BS --list
```

**Expected output:**
```
patient-vitals
lab-results
medications
adverse-events
```

---

#### **C. Describe Topic Configuration**

```bash
# Single topic
kafka-topics --bootstrap-server $BS --describe --topic patient-vitals

# All topics
for topic in patient-vitals lab-results medications adverse-events; do
  echo "========== $topic =========="
  kafka-topics --bootstrap-server $BS --describe --topic $topic
done
```

**Expected output:**
```
Topic: patient-vitals  PartitionCount: 1  ReplicationFactor: 1
    Partition: 0  Leader: 1  Replicas: 1  Isr: 1
```

---

#### **D. Count Messages in Each Topic**

```bash
# Function to count messages
count_messages() {
  topic=$1
  end=$(kafka-get-offsets --bootstrap-server $BS --topic $topic --time -1 | awk -F: '{print $3}')
  begin=$(kafka-get-offsets --bootstrap-server $BS --topic $topic --time -2 | awk -F: '{print $3}')
  count=$((end - begin))
  echo "$topic: $count messages"
}

# Count all topics
for topic in patient-vitals lab-results medications adverse-events; do
  count_messages $topic
done
```

**Expected output:**
```
patient-vitals: 7000 messages
lab-results: 900 messages
medications: 2000 messages
adverse-events: 100 messages
```

---

#### **E. Inspect Message Content**

**View first 5 messages:**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals \
  --from-beginning \
  --max-messages 5
```

**View messages with timestamps:**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals \
  --from-beginning \
  --max-messages 3 \
  --property print.timestamp=true \
  --property print.partition=true \
  --property print.offset=true
```

**Pretty-print JSON (if jq installed):**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals \
  --from-beginning \
  --max-messages 3 | jq .
```

---

#### **F. Watch Live Messages (Real-time Stream)**

**Single topic:**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals
```

**All topics (interleaved):**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --whitelist "patient-vitals|lab-results|medications|adverse-events"
```

**Only NEW messages (not historical):**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals \
  --offset latest
```

**Pretty live stream:**
```bash
kafka-console-consumer \
  --bootstrap-server $BS \
  --topic patient-vitals \
  --property print.timestamp=true | jq .
```

> Press **Ctrl+C** to stop watching

---

#### **G. Check Consumer Group Status**

```bash
# List all consumer groups
kafka-consumer-groups --bootstrap-server $BS --list

# Describe consumer group
kafka-consumer-groups \
  --bootstrap-server $BS \
  --describe \
  --group clinical-consumer-group
```

**Expected output:**
```
GROUP                  TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
clinical-consumer-group patient-vitals  0         7000           7000            0
clinical-consumer-group lab-results     0         900            900             0
```

**LAG = 0** means consumer is caught up! ✅

---

#### **H. Manually Test Producer**

```bash
# Send test message
kafka-console-producer --bootstrap-server $BS --topic patient-vitals

# Paste this JSON and press Ctrl+D
{"patient_id":"PT99999","timestamp":"2025-10-07T18:00:00Z","heart_rate":85,"blood_pressure_systolic":120,"blood_pressure_diastolic":80,"temperature":37.0,"spo2":98,"source":"manual_test","trial_site":"Test Site","trial_arm":"control"}
```

---

### **3. Complete Kafka Inspection Script**

Create `scripts/inspect-kafka.sh`:

```bash
#!/bin/bash
# Complete Kafka inspection script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

BS="localhost:9092"

print_header "1. Kafka Broker Status"
docker exec kafka kafka-broker-api-versions --bootstrap-server $BS | head -1

print_header "2. List All Topics"
docker exec kafka kafka-topics --bootstrap-server $BS --list

print_header "3. Topic Configurations"
for topic in patient-vitals lab-results medications adverse-events; do
    echo -e "${YELLOW}Topic: $topic${NC}"
    docker exec kafka kafka-topics --bootstrap-server $BS --describe --topic $topic
    echo ""
done

print_header "4. Message Counts"
for topic in patient-vitals lab-results medications adverse-events; do
    end=$(docker exec kafka kafka-get-offsets --bootstrap-server $BS --topic $topic --time -1 | awk -F: '{print $3}')
    begin=$(docker exec kafka kafka-get-offsets --bootstrap-server $BS --topic $topic --time -2 | awk -F: '{print $3}')
    count=$((end - begin))
    echo -e "${GREEN}$topic: $count messages${NC}"
done

print_header "5. Consumer Groups"
docker exec kafka kafka-consumer-groups --bootstrap-server $BS --list
echo ""
docker exec kafka kafka-consumer-groups --bootstrap-server $BS --describe --group clinical-consumer-group

print_header "6. Sample Messages (first 3 from patient-vitals)"
docker exec kafka kafka-console-consumer \
    --bootstrap-server $BS \
    --topic patient-vitals \
    --from-beginning \
    --max-messages 3

echo ""
echo -e "${GREEN}✅ Kafka inspection complete!${NC}"
echo ""
echo "To view live messages: docker exec -it kafka bash"
echo "Then run: kafka-console-consumer --bootstrap-server $BS --topic patient-vitals"
```

**Run it:**
```bash
chmod +x scripts/inspect-kafka.sh
./scripts/inspect-kafka.sh
```

---

## 📦 **MinIO Verification**

### **Using MinIO Console (Easiest) 🌐**

1. Open **http://localhost:9001**
2. Login: `minioadmin` / `minioadmin`
3. Click **Buckets** → `clinical-mlops`
4. Navigate: `raw/` → `patient_vitals/` → `date=2025-10-07/` → `hour=XX/`
5. Click on any `batch_*.json` file to preview

**What you'll see:**
```
raw/
├── patient_vitals/
│   └── date=2025-10-07/
│       ├── hour=16/
│       │   ├── batch_20251007_160001_123456.json (156 KB)
│       │   └── batch_20251007_160032_789012.json (158 KB)
│       └── hour=17/
├── lab_results/
├── medications/
└── adverse_events/
```

---

### **Using CLI**

```bash
# List all objects
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls -r myminio/clinical-mlops/raw/

# Count files per topic
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc ls -r myminio/clinical-mlops/raw/patient_vitals/ | wc -l

# Download and view a batch file
docker run --rm --network clinical-mlops_mlops-network \
  minio/mc cat myminio/clinical-mlops/raw/patient_vitals/date=2025-10-07/hour=16/batch_*.json | head -5
```

---

## 🎬 **Complete Verification Workflow**

```bash
# 1. Start everything
docker compose up -d

# 2. Wait for services to be healthy (30 seconds)
sleep 30

# 3. Check Kafka topics exist
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 4. Check producer is generating data
docker logs kafka-producer --tail 20

# 5. Check consumer is writing to MinIO
docker logs kafka-consumer --tail 20

# 6. View data in MinIO Console
open http://localhost:9001

# 7. View topics in Kafka UI
open http://localhost:8090

# 8. Watch live messages
docker exec -it kafka bash
kafka-console-consumer --bootstrap-server localhost:9092 --topic patient-vitals

# View live messages
kafka-console-consumer --bootstrap-server localhost:9092 --topic patient-vitals

# View from beginning
kafka-console-consumer --bootstrap-server localhost:9092 --topic patient-vitals --from-beginning

# View last 10 messages
kafka-console-consumer --bootstrap-server localhost:9092 --topic patient-vitals --from-beginning --max-messages 10


# View patient-vitals
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic patient-vitals

# With pretty JSON formatting (if jq installed)
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic patient-vitals | jq .

# View all 4 topics (open 4 terminals)
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic patient-vitals
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic lab-results
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic medications
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic adverse-events
```

---

## 📊 **Expected Healthy Output**

### **Producer Logs:**
```
2025-10-07 16:30:00 - __main__ - INFO - 🚀 Starting clinical data generation...
2025-10-07 16:30:10 - __main__ - INFO - 📊 Sent 1000 messages | Vitals: 700, Meds: 200, Labs: 90, Adverse: 10
```

### **Consumer Logs:**
```
2025-10-07 16:30:15 - __main__ - INFO - 🚀 Starting clinical data consumer...
2025-10-07 16:30:45 - s3_writer - INFO - ✓ Wrote batch to s3://clinical-mlops/raw/patient_vitals/date=2025-10-07/hour=16/batch_20251007_163045_123456.json (1000 messages)
```

### **Kafka UI:**
- **Brokers**: 1 broker online
- **Topics**: 4 topics with messages
- **Consumer Groups**: `clinical-consumer-group` with LAG=0

### **MinIO Console:**
- Files appearing in `raw/` folder
- Proper date/hour partitioning
- JSON files with ~150KB each

---

## 🔧 **Troubleshooting**

### **No topics appearing in Kafka UI?**
```bash
# Check Kafka is healthy
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# Check producer is running
docker logs kafka-producer

# Manually create topic
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic test-topic --partitions 1 --replication-factor 1
```

### **Consumer not writing to MinIO?**
```bash
# Check consumer logs
docker logs kafka-consumer -f

# Check MinIO is accessible
curl http://localhost:9000/minio/health/live

# Check bucket exists
docker run --rm --network clinical-mlops_mlops-network minio/mc ls myminio/
```

---

## ✅ **Final Checklist**

- [ ] Kafka UI shows 4 topics with messages
- [ ] MinIO Console shows files in `raw/` folder
- [ ] Producer logs show "Sent X messages"
- [ ] Consumer logs show "Wrote batch to s3://"
- [ ] Consumer group LAG = 0
- [ ] Can watch live messages in terminal
- [ ] Sample messages look correct (valid JSON)

---

**Now you have complete visibility into your streaming data pipeline!** 🚀