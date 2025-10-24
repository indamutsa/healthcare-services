# Implementation Roadmap

## 🎯 Project Goal
Transform a monolithic 1,087-line bash script into a modular, maintainable architecture with clear separation of concerns.

---

## 📅 Implementation Phases

### Phase 0: Setup & Foundation (Day 1)
**Goal**: Create folder structure and baseline utilities

#### Tasks
- [ ] Create folder structure
  ```bash
  scripts/
  ├── common/
  ├── infrastructure/
  ├── data-ingestion/
  ├── storage/
  ├── processing-layer/
  ├── ml-layer/
  ├── orchestration-layer/
  └── observability/
  ```

- [ ] Create README.md in each folder explaining purpose
- [ ] Set up Git repository with proper .gitignore

#### Deliverables
- ✅ Folder structure created
- ✅ Each folder has README.md
- ✅ Git repository initialized

#### Success Criteria
- All folders exist
- Directory structure matches architecture plan
- READMEs explain each layer's purpose

---

### Phase 1: Common Utilities Layer (Days 1-2)
**Goal**: Extract reusable functions into shared library

#### Analogy
Think of this like creating a **standard library** for your pipeline. Just like Python's `os`, `sys`, `logging` modules - these are utilities every layer will import and use.

#### Tasks

##### 1.1: Create `common/utils.sh`
- [ ] Color definitions (RED, GREEN, YELLOW, etc.)
- [ ] Logging functions (log_info, log_error, log_success)
- [ ] Docker service checks (check_service_running)
- [ ] Docker compose operations (docker_compose_up, docker_compose_down)
- [ ] Wait functions (wait_for_service, wait_for_services)
- [ ] Status display functions (display_services_status)

**Extracted from original script**: Lines 9-16 (colors), 64-107 (service checks)

##### 1.2: Create `common/config.sh`
- [ ] Layer definitions (LAYER_SERVICES, LAYER_PROFILES, LAYER_NAMES)
- [ ] Dependency mappings (LAYER_DEPENDENCIES)
- [ ] Service-to-layer mappings
- [ ] Helper functions (get_layer_services, get_layer_dependencies)
- [ ] Layer existence validation

**Extracted from original script**: Lines 18-60 (level definitions)

##### 1.3: Create `common/validation.sh`
- [ ] Input validation (validate_level, validate_layer_name)
- [ ] Dependency validation (check_dependencies_met)
- [ ] Configuration validation (validate_config)
- [ ] User input confirmation (confirm_action)

**Extracted from original script**: Lines 976-986, 1008-1018 (validation logic)

#### Testing Strategy
```bash
# Test logging
source common/utils.sh
log_info "Test message"
log_error "Test error"

# Test Docker operations
check_service_running "minio"

# Test configuration
source common/config.sh
get_layer_services "infrastructure"
get_layer_dependencies "ml-layer"
```

#### Deliverables
- ✅ `common/utils.sh` (200 lines)
- ✅ `common/config.sh` (150 lines)
- ✅ `common/validation.sh` (80 lines)
- ✅ Unit tests for each utility function

#### Success Criteria
- All utility functions work in isolation
- No errors when sourcing scripts
- Functions are well-documented with comments

---

### Phase 2: Infrastructure Layer (Days 3-4)
**Goal**: Extract infrastructure management into dedicated layer

#### Analogy
Infrastructure is like the **foundation of a house**. You can't build upper floors (ML, processing) without a solid foundation (databases, storage, message queues).

#### Tasks

##### 2.1: Create `infrastructure/manage.sh`
- [ ] Import common utilities
- [ ] Implement start_layer() function
- [ ] Implement stop_layer() function
- [ ] Implement status_layer() function
- [ ] Implement health_check() function
- [ ] Command router (start, stop, status, health)

**Extracted from original script**: Lines 118-174 (start_level), 255-282 (stop_level_only)

##### 2.2: Create `infrastructure/init-minio.sh`
- [ ] Create buckets (bronze-layer, silver-layer, gold-layer, mlflow-artifacts)
- [ ] Set bucket policies
- [ ] Verify bucket creation

**Extracted from original script**: MinIO initialization logic

##### 2.3: Create `infrastructure/init-postgres.sh`
- [ ] Initialize MLflow database
- [ ] Initialize Airflow database
- [ ] Create required schemas/tables
- [ ] Verify database connectivity

**Extracted from original script**: PostgreSQL initialization logic

##### 2.4: Create `infrastructure/init-kafka.sh`
- [ ] Create Kafka topics (patient-vitals, lab-results, clinical-notes, medical-events)
- [ ] Configure topic partitions and replication
- [ ] Verify topic creation

**Extracted from original script**: Kafka topic creation logic

##### 2.5: Create `infrastructure/health-checks.sh`
- [ ] Check MinIO health
- [ ] Check PostgreSQL connectivity
- [ ] Check Redis connectivity
- [ ] Check Kafka broker health
- [ ] Return aggregated health status

#### Testing Strategy
```bash
# Test infrastructure start
./infrastructure/manage.sh start

# Verify services
docker ps | grep -E "minio|postgres|redis|kafka"

# Test health checks
./infrastructure/health-checks.sh

# Test stop
./infrastructure/manage.sh stop
```

#### Deliverables
- ✅ `infrastructure/manage.sh` (180 lines)
- ✅ `infrastructure/init-minio.sh` (60 lines)
- ✅ `infrastructure/init-postgres.sh` (50 lines)
- ✅ `infrastructure/init-kafka.sh` (60 lines)
- ✅ `infrastructure/health-checks.sh` (70 lines)
- ✅ Integration tests

#### Success Criteria
- Can start infrastructure independently
- All services pass health checks
- Can stop infrastructure cleanly
- Initialization scripts are idempotent (can run multiple times safely)

---

### Phase 3: Data Pipeline Layers (Days 5-6)
**Goal**: Extract data ingestion, storage, and processing layers

#### Analogy
Data pipeline is like a **water treatment plant**:
- **Ingestion**: Raw water intake (data sources)
- **Storage**: Storage tanks (MinIO data lake)
- **Processing**: Treatment process (Spark transformations)

#### Tasks

##### 3.1: Create `data-ingestion/manage.sh`
- [ ] Import common utilities
- [ ] Implement start_layer() with dependency checking
- [ ] Implement stop_layer()
- [ ] Implement validate_kafka_connectivity()
- [ ] Command router

**Extracted from original script**: Data ingestion service management

##### 3.2: Create `storage/manage.sh`
- [ ] Bucket operations (create, delete, list)
- [ ] Data lifecycle management (Bronze → Silver → Gold)
- [ ] Backup and restore utilities
- [ ] Storage metrics collection

**New functionality - not in original script**

##### 3.3: Create `processing-layer/manage.sh`
- [ ] Start Spark cluster
- [ ] Submit Spark jobs
- [ ] Monitor job status
- [ ] Spark cluster health checks

**Extracted from original script**: Spark cluster management (Level 2)

#### Testing Strategy
```bash
# Test complete data pipeline
./infrastructure/manage.sh start
./data-ingestion/manage.sh start
./processing-layer/manage.sh start

# Verify data flow
# 1. Check Kafka has messages
# 2. Verify Bronze layer has data
# 3. Check Spark job processed data
# 4. Verify Silver layer has transformed data
```

#### Deliverables
- ✅ `data-ingestion/manage.sh` (120 lines)
- ✅ `storage/manage.sh` (100 lines)
- ✅ `storage/bucket-ops.sh` (90 lines)
- ✅ `processing-layer/manage.sh` (150 lines)
- ✅ `processing-layer/job-submit.sh` (80 lines)
- ✅ End-to-end data pipeline test

#### Success Criteria
- Data flows from Kafka → MinIO (Bronze) → Spark → MinIO (Silver)
- All layers can be started/stopped independently
- Dependency checking works (processing layer requires ingestion)

---

### Phase 4: ML Pipeline Layer (Days 7-8)
**Goal**: Extract ML and feature engineering functionality

#### Analogy
ML layer is like a **research lab**:
- **Feature Engineering**: Prepare specimens (features)
- **MLflow**: Lab notebook (experiment tracking)
- **Training**: Run experiments
- **Model Serving**: Deploy findings to production

#### Tasks

##### 4.1: Create `ml-layer/manage.sh`
- [ ] Start ML services (feature-engineering, mlflow-server, ml-training, model-serving)
- [ ] Dependency validation
- [ ] ML layer health checks

**Extracted from original script**: Levels 3 and 4 (feature engineering + ML pipeline)

##### 4.2: Create `ml-layer/feature-setup.sh`
- [ ] Initialize feature store (Redis)
- [ ] Create feature schemas
- [ ] Verify feature store connectivity

##### 4.3: Create `ml-layer/mlflow-setup.sh`
- [ ] Initialize MLflow backend store
- [ ] Create default experiments
- [ ] Configure model registry
- [ ] Set up artifact store

##### 4.4: Create `ml-layer/model-ops.sh`
- [ ] Model deployment utilities
- [ ] Model versioning
- [ ] A/B testing setup
- [ ] Model rollback capabilities

#### Testing Strategy
```bash
# Test ML pipeline
./ml-layer/manage.sh start

# Verify MLflow is accessible
curl http://localhost:5001/health

# Check feature store
redis-cli ping

# Verify model registry
mc ls local/mlflow-artifacts/
```

#### Deliverables
- ✅ `ml-layer/manage.sh` (180 lines)
- ✅ `ml-layer/feature-setup.sh` (80 lines)
- ✅ `ml-layer/mlflow-setup.sh` (70 lines)
- ✅ `ml-layer/model-ops.sh` (90 lines)
- ✅ ML pipeline integration test

#### Success Criteria
- MLflow server accessible and tracking experiments
- Feature store operational
- Can train and register models
- Model serving endpoint responds

---

### Phase 5: Orchestration & Observability (Days 9-10)
**Goal**: Extract Airflow and monitoring layers

#### Analogy
- **Orchestration**: Like a **conductor** coordinating an orchestra (Airflow schedules all workflows)
- **Observability**: Like **surveillance cameras** + **security monitors** watching over everything

#### Tasks

##### 5.1: Create `orchestration-layer/manage.sh`
- [ ] Start Airflow services
- [ ] Initialize Airflow (create admin user, connections)
- [ ] DAG deployment utilities
- [ ] Scheduler health checks

**Extracted from original script**: Level 5a (Airflow services)

##### 5.2: Create `orchestration-layer/dag-deploy.sh`
- [ ] Deploy DAGs to Airflow
- [ ] Validate DAG syntax
- [ ] Trigger DAG runs
- [ ] Monitor DAG execution

##### 5.3: Create `observability/manage.sh`
- [ ] Start monitoring services (Prometheus, Grafana, ELK)
- [ ] Initialize dashboards
- [ ] Configure alert rules

**Extracted from original script**: Level 5b (Observability services)

##### 5.4: Create `observability/metrics-setup.sh`
- [ ] Configure Prometheus targets
- [ ] Set up service discovery
- [ ] Create recording rules

##### 5.5: Create `observability/dashboards.sh`
- [ ] Import Grafana dashboards
- [ ] Configure data sources
- [ ] Set up alert channels

#### Testing Strategy
```bash
# Test orchestration
./orchestration-layer/manage.sh start
curl http://localhost:8081/health  # Airflow health

# Test observability
./observability/manage.sh start
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3000/api/health  # Grafana

# Verify metrics collection
curl http://localhost:9090/api/v1/query?query=up
```

#### Deliverables
- ✅ `orchestration-layer/manage.sh` (130 lines)
- ✅ `orchestration-layer/dag-deploy.sh` (60 lines)
- ✅ `observability/manage.sh` (150 lines)
- ✅ `observability/metrics-setup.sh` (70 lines)
- ✅ `observability/dashboards.sh` (80 lines)

#### Success Criteria
- Airflow webserver accessible
- DAGs can be deployed and triggered
- Prometheus collecting metrics
- Grafana dashboards showing data

---

### Phase 6: Main Orchestrator (Days 11-12)
**Goal**: Create main entry point that coordinates all layers

#### Analogy
The orchestrator is like a **system administrator** who knows how to:
- Start services in the right order
- Handle dependencies automatically
- Cascade stops properly
- Provide clear status information

#### Tasks

##### 6.1: Create `pipeline-manager.sh`
- [ ] Import common utilities
- [ ] Parse command-line arguments
- [ ] Implement layer resolution (get dependencies)
- [ ] Implement cascade start (auto-resolve dependencies)
- [ ] Implement cascade stop (stop dependent layers)
- [ ] Implement status display (all layers)
- [ ] Implement rebuild logic (stop → build → start)

**Extracted from original script**: Lines 967-1085 (main script logic)

##### 6.2: Implement Dependency Resolution
```bash
# Pseudo-code
start_layer(layer) {
    deps = get_dependencies(layer)
    for dep in deps:
        if not is_running(dep):
            start_layer(dep)  # Recursive
    
    call layer/manage.sh start
}
```

##### 6.3: Implement Cascade Stop
```bash
# Pseudo-code
stop_layer(layer) {
    dependents = get_dependents(layer)
    for dependent in dependents:
        stop_layer(dependent)  # Stop things that depend on this layer
    
    call layer/manage.sh stop
}
```

##### 6.4: Create Usage Documentation
- [ ] Help message with examples
- [ ] Layer dependency diagram
- [ ] Common troubleshooting tips

#### Testing Strategy
```bash
# Test dependency resolution
./pipeline-manager.sh start ml-layer
# Should auto-start: infrastructure → data-ingestion → processing → ml-layer

# Test cascade stop
./pipeline-manager.sh stop infrastructure
# Should stop: observability → orchestration → ml → processing → ingestion → infrastructure

# Test status
./pipeline-manager.sh status

# Test rebuild
./pipeline-manager.sh rebuild ml-layer
```

#### Deliverables
- ✅ `pipeline-manager.sh` (250 lines)
- ✅ Comprehensive help documentation
- ✅ User guide with examples

#### Success Criteria
- Can start any layer with automatic dependency resolution
- Cascade stop works correctly
- Status shows accurate information for all layers
- Rebuild functionality works end-to-end

---

### Phase 7: Testing & Documentation (Days 13-14)
**Goal**: Comprehensive testing and documentation

#### Tasks

##### 7.1: Integration Testing
- [ ] Test complete pipeline (infrastructure → observability)
- [ ] Test partial pipeline (infrastructure → processing)
- [ ] Test error scenarios (missing dependencies, failed services)
- [ ] Test rebuild scenarios
- [ ] Performance testing (startup time, resource usage)

##### 7.2: Documentation
- [ ] Main README.md (how to use the system)
- [ ] ARCHITECTURE.md (technical architecture)
- [ ] CONTRIBUTING.md (how to add new layers)
- [ ] TROUBLESHOOTING.md (common issues and solutions)
- [ ] Layer-specific READMEs (detailed per-layer docs)

##### 7.3: Migration Guide
- [ ] How to migrate from old `manage_pipeline.sh`
- [ ] Command equivalence table
- [ ] Breaking changes documentation

##### 7.4: Examples
- [ ] Quick start guide
- [ ] Common workflows (dev, production)
- [ ] CI/CD integration examples

#### Deliverables
- ✅ Complete test suite
- ✅ Comprehensive documentation
- ✅ Migration guide
- ✅ Example workflows

#### Success Criteria
- All integration tests pass
- Documentation is clear and comprehensive
- Users can migrate from old script easily

---

## 📊 Progress Tracking

### Overall Progress
```
Phase 0: Setup & Foundation          [████████████████████] 100%
Phase 1: Common Utilities            [                    ]   0%
Phase 2: Infrastructure Layer        [                    ]   0%
Phase 3: Data Pipeline Layers        [                    ]   0%
Phase 4: ML Pipeline Layer           [                    ]   0%
Phase 5: Orchestration & Observability [                  ]   0%
Phase 6: Main Orchestrator           [                    ]   0%
Phase 7: Testing & Documentation     [                    ]   0%
```

### Key Milestones
- [ ] ✅ Phase 0 Complete: Foundation ready
- [ ] ✅ Phase 1 Complete: Common utilities working
- [ ] ✅ Phase 2 Complete: Infrastructure can start independently
- [ ] ✅ Phase 3 Complete: Data pipeline working end-to-end
- [ ] ✅ Phase 4 Complete: ML pipeline operational
- [ ] ✅ Phase 5 Complete: Orchestration and monitoring active
- [ ] ✅ Phase 6 Complete: Main orchestrator functional
- [ ] ✅ Phase 7 Complete: Fully tested and documented

---

## 🎯 Definition of Done (DoD)

For each phase to be considered "done":
1. ✅ All tasks completed
2. ✅ Code follows style guide (comments, naming conventions)
3. ✅ No file exceeds 300 lines
4. ✅ All functions have comments explaining purpose
5. ✅ Integration tests pass
6. ✅ Documentation updated
7. ✅ Code reviewed and approved
8. ✅ No breaking changes to existing functionality (unless intentional)

---

## 📝 Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Original script behavior changes | High | Medium | Thorough testing against original script |
| Missing edge cases | Medium | High | Comprehensive test suite, user feedback |
| Performance degradation | Medium | Low | Benchmark against original script |
| User adoption resistance | High | Medium | Clear migration guide, equivalent commands |
| Incomplete dependency mapping | High | Low | Careful extraction from original script |

---

## ✅ Next Steps

1. **Review this roadmap** - Do you approve the phased approach?
2. **Confirm priorities** - Any phases that should be done first?
3. **Start Phase 1** - Begin with common utilities (lowest risk, highest value)

**Ready to start Phase 1?** 🚀
