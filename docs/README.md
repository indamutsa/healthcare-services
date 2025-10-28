# Set Up the QUEUE

docker run -d \
  --name ibm-mq \
  -p 1414:1414 \
  -p 9443:9443 \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=CLINICAL_QM \
  -e MQ_APP_USER=clinical_app \
  -e MQ_APP_PASSWORD=clinical123 \
  devcoderz2014/ibmmq_9_4_0_0-arm64:1.0


# Pipeline Management - Quick Reference

## 🚀 Start Commands

### Regular Start (Use Cached Images)
```bash
# Start level N and auto-start dependencies
./manage-pipeline.sh --start-level <N>

# Examples:
./manage-pipeline.sh --start-level 0   # Infrastructure only
./manage-pipeline.sh --start-level 2   # Auto-starts 0, 1, 2
./manage-pipeline.sh --start-level 4   # Auto-starts 0, 1, 2, 3, 4
```

### Fresh Start (Rebuild Everything) ⭐ NEW!
```bash
# Stop cascade → Rebuild images → Force recreate
./manage-pipeline.sh --start-level-rebuild <N>

# Examples:
./manage-pipeline.sh --start-level-rebuild 1   # Rebuild levels 0, 1
./manage-pipeline.sh --start-level-rebuild 4   # Rebuild levels 0, 1, 2, 3, 4
```

**When to use rebuild:**
- After code changes in applications
- After Dockerfile modifications
- Need completely fresh containers
- Debugging weird issues

---

## 🛑 Stop Commands

### Cascade Stop (Keeps Volumes)
```bash
# Stops level N and all lower levels (N → 0)
./manage-pipeline.sh --stop-level <N>

# Examples:
./manage-pipeline.sh --stop-level 3   # Stops 3, 2, 1, 0
./manage-pipeline.sh --stop-level 2   # Stops 2, 1, 0
./manage-pipeline.sh --stop-level 1   # Stops 1, 0
```

### Cascade Stop (Removes Volumes) 🗑️
```bash
# Stops level N → 0 and removes ALL volumes
./manage-pipeline.sh --stop-level-full <N>

# Examples:
./manage-pipeline.sh --stop-level-full 3   # Clean slate for levels 3→0
```

---

## 🔄 Other Commands

### Restart (Single Level Only)
```bash
# Restarts only level N (no cascade)
./manage-pipeline.sh --restart-level <N>
```

### View Logs
```bash
# Follow logs for level N services
./manage-pipeline.sh --logs <N>

# Example:
./manage-pipeline.sh --logs 2   # Spark logs
```

### Check Status
```bash
# See what's running
./manage-pipeline.sh --status
```

### Full Stack Operations
```bash
# Start all levels (0-5)
./manage-pipeline.sh --start-full

# Stop all levels (keeps volumes)
./manage-pipeline.sh --stop-full
```

### Nuclear Option 💣
```bash
# Remove EVERYTHING (containers, volumes, images, networks)
./manage-pipeline.sh --clean-all
```

---

## 📊 Level Architecture

| Level | Name | Services | Dependencies | Status |
|-------|------|----------|--------------|--------|
| 0 | Infrastructure | minio, postgres, redis, kafka, zookeeper | None | ✅ Production |
| 1 | Data Ingestion | kafka-producer, kafka-consumer, clinical-mq | 0 | ✅ Production |
| 2 | Data Processing | spark-master, spark-worker, streaming, batch | 0, 1 | ✅ Production |
| 3 | Feature Engineering | feature-engineering | 0, 1, 2 | ✅ Production |
| 4 | ML Pipeline | **mlflow-server**, ml-training, model-serving | 0, 1, 2, 3 | ✅ Production |
| 5 | Orchestration | airflow-scheduler, airflow-webserver, airflow-workers | 0 | ✅ Production |
| 6 | Observability | prometheus, grafana, opensearch, filebeat | 0 | 🚧 In Progress |
| 7 | Platform Engineering | argocd, github-actions-runner, istio, argo-rollouts | 0 | 📋 Planned |
| 8 | Security Testing | metasploit, burp-suite, owasp-zap, trivy | 0 | 📋 Planned |

**Note:** MLflow server moved from Level 0 to Level 4!

---

## 🔻 Cascade Stop Behavior

```
--stop-level 8  →  Stops 8, 7, 6, 5, 4, 3, 2, 1, 0
--stop-level 7  →  Stops 7, 6, 5, 4, 3, 2, 1, 0
--stop-level 6  →  Stops 6, 5, 4, 3, 2, 1, 0
--stop-level 5  →  Stops 5, 4, 3, 2, 1, 0
--stop-level 4  →  Stops 4, 3, 2, 1, 0
--stop-level 3  →  Stops 3, 2, 1, 0
--stop-level 2  →  Stops 2, 1, 0
--stop-level 1  →  Stops 1, 0
--stop-level 0  →  Stops 0 only
```

**Why?** Each level depends on lower levels. Stopping level 3 without stopping levels 2, 1, 0 would leave orphaned dependencies.

---

## 🔄 Rebuild Process

```bash
./manage-pipeline.sh --start-level-rebuild 2
```

**What happens:**
1. **Stop Cascade:** Stops levels 2 → 1 → 0
2. **Rebuild Images:** Rebuilds Docker images for levels 0, 1, 2
3. **Force Recreate:** Starts 0 → 1 → 2 with fresh containers

---

## 🎯 Common Workflows

### Development Workflow (Code Changes)
```bash
# Made changes to kafka-consumer code
./manage-pipeline.sh --start-level-rebuild 1

# Made changes to spark processing
./manage-pipeline.sh --start-level-rebuild 2

# Made changes to feature engineering
./manage-pipeline.sh --start-level-rebuild 3
```

### Testing Workflow
```bash
# Start infrastructure
./manage-pipeline.sh --start-level 0

# Check it's healthy
./manage-pipeline.sh --status

# Add data ingestion
./manage-pipeline.sh --start-level 1

# Add processing
./manage-pipeline.sh --start-level 2

# etc...
```

### Shutdown Workflow
```bash
# Stop everything but keep data
./manage-pipeline.sh --stop-level 8

# Or stop specific level (cascade)
./manage-pipeline.sh --stop-level 2   # Stops 2, 1, 0
```

### Clean Start
```bash
# Remove everything
./manage-pipeline.sh --clean-all

# Fresh rebuild
./manage-pipeline.sh --start-level-rebuild 4
```

---

## 🌐 Access Points

When services are running:

| Service | URL |
|---------|-----|
| MinIO Console | http://localhost:9001 |
| Kafka UI | http://localhost:8090 |
| MLflow UI | http://localhost:5000 |
| Redis UI | http://localhost:5540 |
| Spark Master | http://localhost:8080 |
| Model API | http://localhost:8000 |
| Airflow UI | http://localhost:8081 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| OpenSearch | http://localhost:5601 |

---

## 🆘 Troubleshooting

### Service won't start
```bash
# Check logs
./manage-pipeline.sh --logs <level>

# Force rebuild
./manage-pipeline.sh --start-level-rebuild <level>
```

### Stale containers
```bash
# Clean restart
./manage-pipeline.sh --stop-level-full <level>
./manage-pipeline.sh --start-level-rebuild <level>
```

### Complete reset
```bash
# Nuclear option
./manage-pipeline.sh --clean-all

# Then rebuild from scratch
./manage-pipeline.sh --start-level-rebuild 0
```

---

## 📝 Tips

1. **Use rebuild after code changes** - Ensures Docker images are up to date
2. **Cascade stop saves time** - No need to stop each level individually
3. **Keep volumes by default** - Use `--stop-level-full` only when you want fresh data
4. **Check status often** - `--status` shows what's actually running
5. **Watch logs during startup** - `--logs <N>` helps debug issues

---

## ⚠️ Important Warnings

- **`--stop-level-full`** removes volumes → data loss!
- **`--clean-all`** removes everything → complete reset!
- **Cascade stop** means stopping level 2 also stops levels 1 and 0
- **Rebuild takes time** - Rebuilding all images can take 5-10 minutes

---

## 🎓 Command Comparison

| Command | Stops Cascade? | Rebuilds? | Removes Volumes? |
|---------|----------------|-----------|------------------|
| `--start-level` | No | No | No |
| `--start-level-rebuild` | Yes | Yes | No |
| `--stop-level` | Yes | N/A | No |
| `--stop-level-full` | Yes | N/A | Yes |
| `--restart-level` | No (single) | No | No |
| `--clean-all` | Yes (all) | N/A | Yes + Images |


---

# Pipeline Management Scripts - Cascade Behavior

## 🔄 Unified Cascade Philosophy

Both `manage-pipeline.sh` and `health-check.sh` now use **cascade logic** for consistency:

```
Level N → always includes dependencies (N, N-1, ..., 0)
```

---

## 📊 Side-by-Side Comparison

### **manage-pipeline.sh** (Control)

| Command | Action | Cascade |
|---------|--------|---------|
| `--start-level 3` | Start 3 + deps | ✓ Starts 0→1→2→3 |
| `--stop-level 3` | Stop 3 + deps | ✓ Stops 3→2→1→0 |
| `--start-level-rebuild 3` | Rebuild + start | ✓ Stops 3→0, builds 0→3, starts 0→3 |

### **health-check.sh** (Verify)

| Command | Action | Cascade |
|---------|--------|---------|
| `--level 3` | Check 3 + deps | ✓ Checks 0→1→2→3 |
| `--full` | Check all | Checks 0→1→2→3→4→5 |
| `--status` | Quick status | Shows all levels |

---

## 🎯 Cascade Examples

### Starting Level 3
```bash
# Start with dependencies
./manage-pipeline.sh --start-level 3

# What happens:
# 1. Checks if level 0 running → if not, starts level 0
# 2. Checks if level 1 running → if not, starts level 1
# 3. Checks if level 2 running → if not, starts level 2
# 4. Starts level 3
```

### Stopping Level 3
```bash
# Stop with cascade
./manage-pipeline.sh --stop-level 3

# What happens:
# 1. Stops level 3 ✓
# 2. Stops level 2 ✓
# 3. Stops level 1 ✓
# 4. Stops level 0 ✓
```

### Checking Health of Level 3
```bash
# Check with cascade
./health-check.sh --level 3

# What happens:
# 1. Checks level 0 health ✓
# 2. Checks level 1 health ✓
# 3. Checks level 2 health ✓
# 4. Checks level 3 health ✓
# 5. Checks data flow ✓
```

---

## 🔻 Cascade Behavior Tables

### Start Cascade (Bottom-Up)
```
--start-level 0  →  Starts: 0
--start-level 1  →  Starts: 0 → 1
--start-level 2  →  Starts: 0 → 1 → 2
--start-level 3  →  Starts: 0 → 1 → 2 → 3
--start-level 4  →  Starts: 0 → 1 → 2 → 3 → 4
--start-level 5  →  Starts: 0 → 1 → 2 → 3 → 4 → 5
--start-level 6  →  Starts: 0 → 1 → 2 → 3 → 4 → 5 → 6
--start-level 7  →  Starts: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7
--start-level 8  →  Starts: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
```

### Stop Cascade (Top-Down)
```
--stop-level 0  →  Stops: 0
--stop-level 1  →  Stops: 1 → 0
--stop-level 2  →  Stops: 2 → 1 → 0
--stop-level 3  →  Stops: 3 → 2 → 1 → 0
--stop-level 4  →  Stops: 4 → 3 → 2 → 1 → 0
--stop-level 5  →  Stops: 5 → 4 → 3 → 2 → 1 → 0
--stop-level 6  →  Stops: 6 → 5 → 4 → 3 → 2 → 1 → 0
--stop-level 7  →  Stops: 7 → 6 → 5 → 4 → 3 → 2 → 1 → 0
--stop-level 8  →  Stops: 8 → 7 → 6 → 5 → 4 → 3 → 2 → 1 → 0
```

### Health Check Cascade (Bottom-Up)
```
--level 0  →  Checks: 0
--level 1  →  Checks: 0 → 1
--level 2  →  Checks: 0 → 1 → 2
--level 3  →  Checks: 0 → 1 → 2 → 3
--level 4  →  Checks: 0 → 1 → 2 → 3 → 4
--level 5  →  Checks: 0 → 1 → 2 → 3 → 4 → 5
--level 6  →  Checks: 0 → 1 → 2 → 3 → 4 → 5 → 6
--level 7  →  Checks: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7
--level 8  →  Checks: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
```

---

## 🔄 Complete Workflow Example

### 1. Fresh Start
```bash
# Start level 2 (data processing) with fresh rebuild
./manage-pipeline.sh --start-level-rebuild 2

# Process:
# 1. Stop cascade: 2 → 1 → 0
# 2. Rebuild images: 0, 1, 2
# 3. Start cascade: 0 → 1 → 2
```

### 2. Health Check
```bash
# Check level 2 health (includes dependencies)
./health-check.sh --level 2

# Process:
# 1. Check level 0: ✓ Infrastructure healthy
# 2. Check level 1: ✓ Data ingestion healthy
# 3. Check level 2: ✓ Data processing healthy
# 4. Check data flow: ✓ Data flowing
```

### 3. View Status
```bash
# Quick status check
./manage-pipeline.sh --status

# Shows all levels:
# Level 0: Infrastructure     ✓ 9/9 running
# Level 1: Data Ingestion     ✓ 3/6 running
# Level 2: Data Processing    ✓ 4/4 running
# Level 3: Feature Engineering ✗ 0/1 running
# ...
```

### 4. Stop When Done
```bash
# Stop level 2 (cascade down)
./manage-pipeline.sh --stop-level 2

# Process:
# 1. Stop level 2: spark services
# 2. Stop level 1: kafka services
# 3. Stop level 0: infrastructure
```

---

## 💡 Why Cascade?

### Starting (Bottom-Up)
**Why?** Each level needs its dependencies running first.
```
Level 3 needs: Level 2 (processing)
Level 2 needs: Level 1 (ingestion)
Level 1 needs: Level 0 (infrastructure)

Therefore: Start 0 → 1 → 2 → 3
```

### Stopping (Top-Down)
**Why?** Higher levels depend on lower levels. Stopping lower levels first would break higher levels.
```
Level 0 stopped = Level 1 broken = Level 2 broken = Level 3 broken

Therefore: Stop 3 → 2 → 1 → 0
```

### Health Checking (Bottom-Up)
**Why?** Root causes are usually in lower levels. Check foundations first.
```
Level 3 failing? Check level 2
Level 2 failing? Check level 1
Level 1 failing? Check level 0

Therefore: Check 0 → 1 → 2 → 3
```

---

## 🎓 Mental Model

Think of the pipeline as a **building**:

```
┌─────────────────────────┐
│  Level 8: Security      │  ← 8th floor
├─────────────────────────┤
│  Level 7: Platform Eng  │  ← 7th floor
├─────────────────────────┤
│  Level 6: Observability │  ← 6th floor
├─────────────────────────┤
│  Level 5: Orchestration │  ← 5th floor
├─────────────────────────┤
│  Level 4: ML Pipeline   │  ← 4th floor
├─────────────────────────┤
│  Level 3: Features      │  ← 3rd floor
├─────────────────────────┤
│  Level 2: Processing    │  ← 2nd floor
├─────────────────────────┤
│  Level 1: Ingestion     │  ← 1st floor
├─────────────────────────┤
│  Level 0: Infrastructure│  ← Foundation
└─────────────────────────┘
```

**Starting:** Build from foundation up (0 → 8)
**Stopping:** Demolish from top down (8 → 0)
**Checking:** Inspect from foundation up (0 → 8)

---

## 📋 Quick Command Reference

### manage-pipeline.sh
```bash
# Start with dependencies
./manage-pipeline.sh --start-level <N>

# Fresh start (rebuild)
./manage-pipeline.sh --start-level-rebuild <N>

# Stop with cascade
./manage-pipeline.sh --stop-level <N>

# Stop with cascade + remove volumes
./manage-pipeline.sh --stop-level-full <N>

# Status check
./manage-pipeline.sh --status

# View logs
./manage-pipeline.sh --logs <N>
```

### health-check.sh
```bash
# Check level + dependencies
./health-check.sh --level <N>

# Full pipeline health check
./health-check.sh --full

# Quick status
./health-check.sh --status

# Data flow only
./health-check.sh --data-flow
```

---

## ⚠️ Important Notes

1. **Cascade is NOT optional** - It's built into the design
2. **Start cascade goes UP** (0→N) - Dependencies first
3. **Stop cascade goes DOWN** (N→0) - Dependents first
4. **Health cascade goes UP** (0→N) - Check foundations first
5. **Level 0 is special** - No dependencies, foundation for all

---

## 🚀 Common Patterns

### Development Workflow
```bash
# Make code changes
# ...

# Rebuild affected level
./manage-pipeline.sh --start-level-rebuild 2

# Verify health
./health-check.sh --level 2

# Check data flow
./health-check.sh --data-flow
```

### Debugging Workflow
```bash
# Service failing
./manage-pipeline.sh --status

# Identify level
# Level 3 has issues

# Check health with cascade
./health-check.sh --level 3

# View logs
./manage-pipeline.sh --logs 3

# Restart with rebuild
./manage-pipeline.sh --start-level-rebuild 3
```

### Clean Shutdown
```bash
# Stop everything cleanly
./manage-pipeline.sh --stop-level 8

# Or just stop up to level you need
./manage-pipeline.sh --stop-level 2  # Stops 2,1,0 only
```

---

## 📊 Comparison Matrix

| Operation | manage-pipeline | health-check | Direction | Cascade |
|-----------|----------------|--------------|-----------|---------|
| Start Level N (0-8) | `--start-level N` | N/A | ⬆️ Up (0→N) | Auto-deps |
| Stop Level N (0-8) | `--stop-level N` | N/A | ⬇️ Down (N→0) | Forced |
| Check Level N (0-8) | N/A | `--level N` | ⬆️ Up (0→N) | Auto-deps |
| Rebuild N (0-8) | `--start-level-rebuild N` | N/A | 🔄 Both | Stop N→0, Build 0→N |

---

## ✅ Consistency Rules

Both scripts follow these rules:

1. **Level dependencies are immutable**
   - Level 1 always depends on 0
   - Level 2 always depends on 0, 1
   - etc.

2. **Operations respect dependencies**
   - Can't start level 2 without level 0, 1
   - Stopping level 2 also stops levels 1, 0
   - Can't check level 2 without checking 0, 1

3. **MLflow moved to Level 4**
   - Previously in Level 0 (Infrastructure)
   - Now in Level 4 (ML Pipeline)
   - Makes logical sense: ML infra with ML services

4. **Cascade is always mentioned**
   - Help text explains cascade
   - Scripts show what will be affected
   - Users are never surprised