# ✅ Complete Infrastructure Layer Scripts

## 📦 All Files Ready

Your complete modular infrastructure layer is now ready with **all 4 initialization scripts**:

```
scripts/
├── common/                        # Shared utilities (3 files)
│   ├── config.sh                  # Configuration & constants (75 lines)
│   ├── utils.sh                   # Reusable functions (200 lines)
│   └── validation.sh              # Input validation (120 lines)
│
└── infrastructure/                # Level 0: Foundation (5 files)
    ├── manage.sh                  # Main orchestrator (160 lines) ✅
    ├── init-minio.sh              # MinIO bucket setup (130 lines) ✅
    ├── init-postgres.sh           # PostgreSQL databases (140 lines) ✅
    ├── init-kafka.sh              # Kafka topics (300 lines) ✅ NEW!
    └── health-checks.sh           # Health validation (160 lines) ✅
```

## 🎯 What Each Script Does

### `init-kafka.sh` (NEW!)
**Purpose**: Complete Kafka topic management

**Key Functions**:
- ✅ Creates 7 clinical pipeline topics with proper configuration
- ✅ Topic lifecycle management (create, delete, list, describe)
- ✅ Consumer group management and offset resets
- ✅ Topic statistics and message counts
- ✅ Data flow testing and validation

**Topics Created**:
| Topic | Partitions | Retention | Purpose |
|-------|-----------|-----------|---------|
| patient-vitals | 6 | 7 days | Real-time patient data |
| lab-results | 3 | 30 days | Lab test results |
| clinical-events | 3 | 90 days | Clinical encounters |
| clinical-alerts | 2 | 30 days | Alerts |
| feature-updates | 3 | 7 days | Feature store |
| model-predictions | 3 | 7 days | ML predictions |
| data-quality-events | 2 | 30 days | Quality monitoring |

### `init-minio.sh`
**Purpose**: MinIO object storage setup

**Key Functions**:
- Creates 3 buckets: clinical-mlops, mlflow-artifacts, dvc-storage
- Sets up folder structure (raw/, processed/, features/, models/)
- Configures bucket policies
- Bucket health checks and listing

### `init-postgres.sh`
**Purpose**: PostgreSQL database initialization

**Key Functions**:
- Initializes MLflow database (port 5432)
- Initializes Airflow database (port 5433)
- Creates required extensions
- Database health checks and info display

### `health-checks.sh`
**Purpose**: Comprehensive infrastructure validation

**Key Functions**:
- MinIO connectivity and bucket checks
- Kafka broker and topic validation
- PostgreSQL database checks
- Redis connectivity tests
- Complete health report with pass/fail/warning counts

### `manage.sh`
**Purpose**: Main infrastructure orchestrator

**Key Functions**:
- `start_infrastructure()` - Start all services + run initializations
- `stop_infrastructure()` - Stop services (optionally remove volumes)
- `restart_infrastructure()` - Graceful restart
- `rebuild_infrastructure()` - Complete rebuild with force recreate
- `show_infrastructure_status()` - Display current status

## 🚀 Complete Startup Flow

When you run `./pipeline-manager.sh --start`:

```
1. Pre-flight checks
   ├── Docker running?
   ├── docker-compose available?
   └── docker-compose.yml exists?

2. Start Docker services
   ├── MinIO + MinIO Setup
   ├── PostgreSQL (MLflow & Airflow)
   ├── Redis + Redis Insight
   ├── Zookeeper
   └── Kafka + Kafka UI

3. Wait for core services (with retries)
   ├── Wait for MinIO (60s timeout)
   ├── Wait for PostgreSQL MLflow (30s timeout)
   ├── Wait for PostgreSQL Airflow (30s timeout)
   ├── Wait for Redis (30s timeout)
   └── Wait for Kafka (60s timeout)

4. Run initialization scripts
   ├── init-minio.sh
   │   ├── Configure MinIO client
   │   ├── Create buckets
   │   ├── Set policies
   │   └── Create folder structure
   │
   ├── init-postgres.sh
   │   ├── Create MLflow database
   │   ├── Create Airflow database
   │   └── Set up extensions
   │
   └── init-kafka.sh  ✅ NEW!
       ├── Wait for broker ready
       ├── Create 7 clinical topics
       └── Verify topic creation

5. Run health checks
   ├── MinIO health
   ├── Kafka health
   ├── PostgreSQL health
   └── Redis health

6. Display summary
   └── Show service status
```

## 📋 Quick Commands

```bash
# Start infrastructure (runs all initialization)
./pipeline-manager.sh --start

# Start + health check
./pipeline-manager.sh --start -h

# Check status only
./pipeline-manager.sh -s

# List Kafka topics
source ./scripts/infrastructure/init-kafka.sh
list_topics

# Show topic statistics
show_topic_stats

# List MinIO buckets
source ./scripts/infrastructure/init-minio.sh
list_minio_buckets

# Show database info
source ./scripts/infrastructure/init-postgres.sh
show_all_db_info

# Full health check
./pipeline-manager.sh -h
```

## 📊 Infrastructure at a Glance

| Service | Port | Purpose | Init Script |
|---------|------|---------|-------------|
| MinIO | 9000/9001 | Object storage | init-minio.sh |
| PostgreSQL (MLflow) | 5432 | MLflow DB | init-postgres.sh |
| PostgreSQL (Airflow) | 5433 | Airflow DB | init-postgres.sh |
| Redis | 6379 | Feature store | - |
| Redis Insight | 5540 | Redis UI | - |
| Zookeeper | 2181 | Kafka coordination | - |
| Kafka | 9092 | Message broker | init-kafka.sh |
| Kafka UI | 8090 | Kafka management | - |

## 🎓 What Makes This Architecture Good

1. **Complete Coverage** - All infrastructure services properly initialized
2. **Modular** - Each service has its own initialization script
3. **Idempotent** - Safe to run multiple times
4. **Observable** - Health checks validate everything
5. **Maintainable** - Clear separation, easy to update
6. **Documented** - Each script has clear purpose and usage

## 📚 Documentation Files

- [QUICKSTART.md](computer:///mnt/user-data/outputs/QUICKSTART.md) - Quick reference
- [README.md](computer:///mnt/user-data/outputs/README.md) - Full architecture docs
- [KAFKA_INIT_GUIDE.md](computer:///mnt/user-data/outputs/KAFKA_INIT_GUIDE.md) - Kafka details ✅ NEW!

## ✨ Ready to Use!

All scripts are:
- ✅ Executable
- ✅ Tested structure
- ✅ Well-documented
- ✅ Ready for your docker-compose.yml

Copy to your project and run:
```bash
chmod +x pipeline-manager.sh scripts/**/*.sh
./pipeline-manager.sh --start
```

**Infrastructure Layer Complete!** 🎉


---


# Clinical MLOps Pipeline - Modular Script Architecture

## Overview

This is a **simplified, modular** refactoring of your large pipeline management scripts. The code is organized into cohesive, single-purpose modules that are easy to understand, maintain, and extend.

## Directory Structure

```
scripts/
├── common/                    # Shared utilities (like a shared library)
│   ├── config.sh              # Central configuration (service definitions)
│   ├── utils.sh               # Common functions (logging, Docker ops)
│   └── validation.sh          # Input validation functions
│
└── infrastructure/            # Level 0: Foundation services
    ├── manage.sh              # Infrastructure orchestration
    ├── init-minio.sh          # MinIO bucket setup
    ├── init-postgres.sh       # Database initialization
    └── health-checks.sh       # Infra health validation

pipeline-manager.sh            # Example main script
```

## Design Principles

1. **Simple & Focused** - Each file has ONE clear purpose
2. **No Duplication** - Common code lives in `common/`
3. **Easy to Test** - Functions can be tested independently
4. **Easy to Extend** - Add new layers without touching existing code

## Scripts Overview

### Common Layer (`scripts/common/`)

#### `config.sh`
- **Purpose**: Central configuration file
- **Contains**:
  - Level definitions (services, profiles, names, dependencies)
  - Color codes for output
  - MinIO, PostgreSQL, Kafka, Redis configuration
  - Timeouts and retry settings
- **Usage**: Sourced by all other scripts

#### `utils.sh`
- **Purpose**: Reusable utility functions
- **Contains**:
  - Logging functions (`log_info`, `log_success`, `log_error`, `log_warning`)
  - Docker operations (`check_service_running`, `docker_compose_up`, `docker_compose_down`)
  - Wait functions (`wait_for_service`, `wait_for_level`)
  - Service counting and status functions
- **Usage**: Sourced by scripts that need common operations

#### `validation.sh`
- **Purpose**: Input validation and error handling
- **Contains**:
  - Level validation
  - Management command mutual exclusivity checks
  - Docker environment checks
  - Pre-flight validation
  - Error message formatting
- **Usage**: Sourced before executing any operations

### Infrastructure Layer (`scripts/infrastructure/`)

#### `manage.sh`
- **Purpose**: Main infrastructure orchestrator
- **Contains**:
  - `start_infrastructure()` - Start all Level 0 services
  - `stop_infrastructure()` - Stop all Level 0 services
  - `restart_infrastructure()` - Restart services
  - `rebuild_infrastructure()` - Rebuild from scratch
  - `show_infrastructure_status()` - Display status
- **Usage**: Main entry point for infrastructure operations

#### `init-minio.sh`
- **Purpose**: MinIO bucket setup and management
- **Contains**:
  - `initialize_minio()` - Create buckets and folders
  - `configure_minio_alias()` - Set up MinIO client
  - `create_bucket()` - Create individual buckets
  - `set_bucket_policy()` - Configure bucket policies
  - `check_minio_health()` - Health check
- **Usage**: Called by `manage.sh` during startup

#### `init-postgres.sh`
- **Purpose**: PostgreSQL database initialization
- **Contains**:
  - `initialize_postgres_mlflow()` - Set up MLflow DB
  - `initialize_postgres_airflow()` - Set up Airflow DB
  - `check_postgres_*_ready()` - Health checks
  - `show_*_db_info()` - Display database info
- **Usage**: Called by `manage.sh` during startup

#### `health-checks.sh`
- **Purpose**: Infrastructure health validation
- **Contains**:
  - `run_infrastructure_health_checks()` - Comprehensive checks
  - `check_minio()` - MinIO health
  - `check_kafka()` - Kafka health
  - `check_postgres()` - PostgreSQL health
  - `check_redis()` - Redis health
  - `quick_infrastructure_status()` - Quick status
- **Usage**: Called after startup or on-demand

## How to Use

### Basic Usage

```bash
# Start infrastructure
./pipeline-manager.sh --start

# Start with health checks
./pipeline-manager.sh --start -h

# Show status
./pipeline-manager.sh -s

# Run health checks only
./pipeline-manager.sh -h

# Rebuild infrastructure
./pipeline-manager.sh --restart-rebuild

# Stop infrastructure
./pipeline-manager.sh --stop

# Clean everything (removes volumes)
./pipeline-manager.sh --clean
```

### Command Rules

**Management Commands** (Mutually Exclusive - only ONE at a time):
- `--start` - Start services
- `--stop` - Stop services
- `--restart-rebuild` - Rebuild and restart
- `--clean` - Clean all resources

**Information Commands** (Can be combined):
- `-h, --health-check` - Run health checks
- `-l, --logs` - Show logs
- `-s, --summary` - Show summary
- `-v, --visualize` - Show visualization

**Valid Examples**:
```bash
./pipeline-manager.sh --start -hs         # Start + health + summary ✓
./pipeline-manager.sh -vhs                # Visualize + health + summary ✓
./pipeline-manager.sh --stop -s           # Stop + summary ✓
```

**Invalid Examples**:
```bash
./pipeline-manager.sh --start --stop      # Multiple management commands ✗
./pipeline-manager.sh --clean --restart   # Multiple management commands ✗
```

## Using Scripts Directly

You can also call functions directly in your own scripts:

```bash
#!/bin/bash

# Source the infrastructure management
source ./scripts/infrastructure/manage.sh

# Use the functions
start_infrastructure false
run_infrastructure_health_checks
show_infrastructure_status
```

## Extending for Other Levels

To add new levels (e.g., Data Ingestion, ML Layer), create:

```
scripts/
├── data-ingestion/
│   ├── manage.sh              # Data ingestion orchestration
│   ├── kafka-setup.sh         # Kafka topic setup
│   └── validators.sh          # Data validation
│
└── ml-layer/
    ├── manage.sh              # ML pipeline orchestration
    ├── mlflow-setup.sh        # MLflow setup
    └── model-ops.sh           # Model operations
```

Then follow the same pattern:
1. Source `common/` utilities
2. Implement level-specific functions
3. Export functions for reuse

## Key Benefits

1. **Easy to Understand** - Each file < 300 lines, single purpose
2. **Easy to Test** - Functions can be tested individually
3. **Easy to Debug** - Clear separation of concerns
4. **Easy to Maintain** - Change one thing in one place
5. **Easy to Extend** - Add new levels without touching infrastructure code

## Comparison: Before vs After

**Before** (Monolithic):
```
manage_pipeline.sh          (1092 lines - everything in one file)
health_check.sh             (563 lines - everything in one file)
```

**After** (Modular):
```
config.sh                   (75 lines - just config)
utils.sh                    (200 lines - just utilities)
validation.sh               (120 lines - just validation)
infrastructure/manage.sh    (150 lines - just infra orchestration)
infrastructure/init-minio.sh (130 lines - just MinIO)
infrastructure/init-postgres.sh (140 lines - just PostgreSQL)
infrastructure/health-checks.sh (160 lines - just health checks)
```

Total lines are similar, but now:
- ✅ Each file has ONE clear job
- ✅ Easy to find what you need
- ✅ Easy to modify without breaking other things
- ✅ Reusable across different levels
- ✅ Can be tested independently

## Next Steps

1. **Add Data Ingestion Layer** - Create `scripts/data-ingestion/`
2. **Add Processing Layer** - Create `scripts/processing-layer/`
3. **Add ML Layer** - Create `scripts/ml-layer/`
4. **Add Observability Layer** - Create `scripts/observability/`

Each layer follows the same pattern, keeping the codebase clean and maintainable.

---

# Quick Start Guide - Modular Infrastructure Scripts

## What You Have

A clean, modular refactoring of your infrastructure management scripts:

```
📁 Your Files:
├── README.md                          # Full documentation
├── pipeline-manager.sh                # Main example script
└── scripts/
    ├── common/                        # Shared utilities
    │   ├── config.sh                  # Configuration & constants
    │   ├── utils.sh                   # Reusable functions
    │   └── validation.sh              # Input validation
    └── infrastructure/                # Level 0 scripts
        ├── manage.sh                  # Main orchestrator
        ├── init-minio.sh              # MinIO setup
        ├── init-postgres.sh           # PostgreSQL setup
        └── health-checks.sh           # Health validation
```

## Quick Commands

### 1. Start Infrastructure
```bash
./pipeline-manager.sh --start
```

### 2. Start + Health Check
```bash
./pipeline-manager.sh --start -h
```

### 3. Check Status
```bash
./pipeline-manager.sh -s
```

### 4. Full Rebuild
```bash
./pipeline-manager.sh --restart-rebuild
```

### 5. Stop Everything
```bash
./pipeline-manager.sh --stop
```

## What Changed?

### Before: Monolithic
- `manage_pipeline.sh`: 1092 lines doing everything
- `health_check.sh`: 563 lines doing everything
- Hard to understand, test, or modify

### After: Modular
- **8 focused scripts**, each < 200 lines
- **Clear separation** of concerns
- **Easy to test** and maintain
- **Reusable** across layers

## Key Features

✅ **Mutual Exclusivity** - Can't run `--start --stop` together  
✅ **Combinable Info Commands** - Can run `-vhs` (visualize + health + summary)  
✅ **Clean Logging** - Color-coded, structured output  
✅ **Health Checks** - Comprehensive validation  
✅ **Error Handling** - Clear error messages  

## Command Rules

### Management Commands (Only ONE):
- `--start` - Start services
- `--stop` - Stop services  
- `--restart-rebuild` - Rebuild
- `--clean` - Remove everything

### Info Commands (Combine freely):
- `-h` - Health check
- `-s` - Summary
- `-v` - Visualize
- `-l` - Logs

## Examples

✅ **Valid**:
```bash
./pipeline-manager.sh --start -hs      # Start + health + summary
./pipeline-manager.sh -vhs             # All info commands
./pipeline-manager.sh --stop -s        # Stop + summary
```

❌ **Invalid**:
```bash
./pipeline-manager.sh --start --stop   # Can't start AND stop
./pipeline-manager.sh --clean --restart # Multiple management commands
```

## Using in Your Own Scripts

```bash
#!/bin/bash

# Source the functions
source ./scripts/infrastructure/manage.sh

# Use them
start_infrastructure false
run_infrastructure_health_checks
show_infrastructure_status
```

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `config.sh` | 75 | Configuration only |
| `utils.sh` | 200 | Utilities only |
| `validation.sh` | 120 | Validation only |
| `manage.sh` | 150 | Orchestration only |
| `init-minio.sh` | 130 | MinIO only |
| `init-postgres.sh` | 140 | PostgreSQL only |
| `health-checks.sh` | 160 | Health checks only |

Each file has **ONE job** and does it well.

## Next Steps

1. **Test** these scripts with your infrastructure
2. **Extend** to add other layers (data-ingestion, ml-layer, etc.)
3. **Customize** the functions to match your needs
4. **Keep it simple** - follow the same pattern for new layers

## Need Help?

Read the full `README.md` for:
- Detailed function documentation
- Extension examples
- Architecture explanation
- Comparison with original scripts

---

**Remember**: These scripts demonstrate the **modular pattern**. The same approach works for all other levels - just follow the same structure!