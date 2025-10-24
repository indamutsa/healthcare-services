# Level-Based Pipeline Management System

## 📦 What You've Received

Complete level-based management system for your Clinical MLOps pipeline with clean separation of concerns and proper lifecycle management.

## 📁 Files Delivered

### 1. **manage_pipeline.sh** (19 KB)
**The main management script** - your single entry point for all pipeline operations.

**Key capabilities:**
- Start/stop services by level
- Automatic dependency management
- Volume preservation options
- Full cleanup (removes everything including images)
- Status monitoring
- Log viewing

**Make it executable:**
```bash
chmod +x manage_pipeline.sh
```

---

### 2. **LEVEL_BASED_MANAGEMENT_GUIDE.md** (10 KB)
**Comprehensive documentation** covering:
- Architecture overview
- Required docker-compose changes
- Complete usage examples
- Troubleshooting guide
- Best practices

**Read this for:**
- Understanding the system
- Docker-compose configuration changes
- Detailed workflow examples

---

### 3. **QUICK_REFERENCE.txt** (14 KB)
**Command cheat sheet** with:
- All commands at a glance
- Copy-paste examples
- Access points (URLs)
- Common workflows

**Use this when:**
- You need a quick command
- You forgot the syntax
- You want copy-paste examples

---

### 4. **ARCHITECTURE_DIAGRAM.txt** (14 KB)
**Visual ASCII architecture** showing:
- Level dependencies
- Service groupings
- Before/after comparison
- Example workflows

**Use this when:**
- You need to visualize the system
- Explaining to team members
- Understanding dependencies

---

### 5. **SETUP_CHECKLIST.txt** (13 KB)
**Step-by-step verification** including:
- Docker-compose modification steps
- Test procedures
- Success criteria
- Troubleshooting

**Use this when:**
- Setting up for the first time
- Verifying configuration
- Something isn't working

---

### 6. **docker-compose-level4-section.yml** (2.6 KB)
**Example configuration** for Level 4 showing:
- How to add profiles to mlflow-server
- Correct ml-training configuration
- Correct model-serving configuration

**Use this as:**
- Reference when editing docker-compose.yml
- Template for the profile addition

---

### 7. **setup.sh** (2.8 KB)
**Quick setup helper** that:
- Backs up docker-compose.yml
- Guides you through manual changes
- Validates configuration
- Sets permissions

**Run this to:**
- Get guided through setup
- Ensure nothing is missed

---

## 🚀 Quick Start (3 Steps)

### Step 1: Update docker-compose.yml

Add profiles to mlflow-server, ml-training, and model-serving:

```yaml
mlflow-server:
  # ... existing config ...
  profiles:
    - ml-pipeline    # 👈 ADD THIS
```

### Step 2: Set up the script

```bash
chmod +x manage_pipeline.sh
```

### Step 3: Test it

```bash
# Start infrastructure
./manage_pipeline.sh --start-level 0

# Verify MLflow is NOT running (should show ✗)
./manage_pipeline.sh --status

# Start ML Pipeline
./manage_pipeline.sh --start-level 4

# Verify MLflow IS running now (should show ✓)
./manage_pipeline.sh --status

# Access MLflow
open http://localhost:5000
```

---

## 🎯 Key Changes from Old System

### OLD: MLflow in Level 0
```bash
./manage_pipeline.sh --start-level 0
# ❌ MLflow starts immediately (wasteful)
```

### NEW: MLflow in Level 4
```bash
./manage_pipeline.sh --start-level 0
# ✅ Only infrastructure starts

./manage_pipeline.sh --start-level 4
# ✅ MLflow starts with ML training and serving
```

### Benefits:
- **Resource efficiency**: Don't run MLflow unnecessarily
- **Logical grouping**: ML tools together with ML pipeline
- **Better separation**: Infrastructure vs ML concerns
- **Cleaner management**: Start only what you need

---

## 📊 Level Overview

| Level | Name | Key Services | When to Use |
|-------|------|--------------|-------------|
| **0** | Infrastructure | MinIO, Postgres, Redis, Kafka | Always - base layer |
| **1** | Data Ingestion | Kafka Producer/Consumer | Testing data flow |
| **2** | Data Processing | Spark Streaming/Batch | Processing pipelines |
| **3** | Feature Engineering | Feature service | ML feature work |
| **4** | ML Pipeline | **MLflow**, Training, Serving | Model training/serving |
| **5** | Observability | Airflow, Prometheus, Grafana | Monitoring/orchestration |

---

## 🔨 Most Common Commands

```bash
# Start infrastructure
./manage_pipeline.sh --start-level 0

# Start everything
./manage_pipeline.sh --start-full

# Check status
./manage_pipeline.sh --status

# View logs
./manage_pipeline.sh --logs 2

# Stop level (keep data)
./manage_pipeline.sh --stop-level 3

# Stop level (remove data)
./manage_pipeline.sh --stop-level-full 3

# Nuclear option (remove everything)
./manage_pipeline.sh --clean-all

# Get help
./manage_pipeline.sh --help
```

---

## 📖 Documentation Reading Order

**For first-time setup:**
1. Read: **SETUP_CHECKLIST.txt** (follow step-by-step)
2. Reference: **docker-compose-level4-section.yml** (for edits)
3. Verify: Run the checklist tests

**For understanding the system:**
1. Read: **LEVEL_BASED_MANAGEMENT_GUIDE.md** (comprehensive)
2. View: **ARCHITECTURE_DIAGRAM.txt** (visual overview)
3. Bookmark: **QUICK_REFERENCE.txt** (for daily use)

**For daily use:**
- Keep **QUICK_REFERENCE.txt** handy
- Use `./manage_pipeline.sh --help`

---

## 🎨 Access Points

Once services are running:

| Service | URL | Level | Credentials |
|---------|-----|-------|-------------|
| MinIO Console | http://localhost:9001 | 0 | minioadmin / minioadmin |
| Kafka UI | http://localhost:8090 | 0 | - |
| Redis Insight | http://localhost:5540 | 0 | - |
| MLflow UI | http://localhost:5000 | **4** | - |
| Spark Master | http://localhost:8080 | 2 | - |
| Model API | http://localhost:8000 | 4 | - |
| Airflow | http://localhost:8081 | 5 | admin / admin |
| Prometheus | http://localhost:9090 | 5 | - |
| Grafana | http://localhost:3000 | 5 | admin / admin |
| OpenSearch | http://localhost:5601 | 5 | - |

---

## 🐛 Troubleshooting

### MLflow still starts at Level 0?
**Problem**: MLflow-server doesn't have the profile
**Solution**: Check docker-compose.yml has `profiles: [ml-pipeline]` under mlflow-server

### Services won't start?
**Problem**: Dependencies not running
**Solution**: `./manage_pipeline.sh --status` then start dependencies

### Need to reset everything?
**Problem**: System in bad state
**Solution**: `./manage_pipeline.sh --clean-all` then start fresh

### Out of disk space?
**Problem**: Too many volumes/images
**Solution**: `./manage_pipeline.sh --clean-all` (removes everything)

---

## ✅ Success Criteria

You'll know the system is working correctly when:

- ✅ `./manage_pipeline.sh --help` shows usage
- ✅ `./manage_pipeline.sh --start-level 0` starts only infrastructure
- ✅ MLflow is **NOT** running at Level 0
- ✅ `./manage_pipeline.sh --start-level 4` starts MLflow
- ✅ MLflow **IS** running at Level 4
- ✅ `./manage_pipeline.sh --status` shows correct states
- ✅ `./manage_pipeline.sh --clean-all` removes everything
- ✅ Can access all UIs at their respective URLs

---

## 🎯 Next Steps

1. **Apply the changes**: Follow SETUP_CHECKLIST.txt
2. **Test thoroughly**: Run through all test scenarios
3. **Start building**: Use the pipeline for your ML work
4. **Refer to docs**: Keep QUICK_REFERENCE.txt handy

---

## 📞 Need Help?

Refer to these files in order:

1. **QUICK_REFERENCE.txt** - For common commands
2. **SETUP_CHECKLIST.txt** - For setup issues
3. **LEVEL_BASED_MANAGEMENT_GUIDE.md** - For detailed explanations
4. **ARCHITECTURE_DIAGRAM.txt** - For understanding structure

---

## 🎉 Summary

You now have a **professional level-based management system** that:

- ✅ Provides clean separation of concerns
- ✅ Manages dependencies automatically
- ✅ Allows selective service startup
- ✅ Preserves or removes data as needed
- ✅ Removes everything with one command
- ✅ Is documented comprehensively

**The key change**: MLflow moved from Level 0 to Level 4 for better organization and resource efficiency.

---

**Files are ready in `/mnt/user-data/outputs/`** 🚀

Good luck with your Clinical MLOps pipeline!