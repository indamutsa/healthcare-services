  ---
  Clinical MLOps Pipeline Manager - LLM Instructions

  System Architecture

  Hierarchical 6-level pipeline where each level includes all dependencies below it:

  | Level | Name                | Key Services                                                     |
  |-------|---------------------|------------------------------------------------------------------|
  | 0     | Infrastructure      | MinIO, PostgreSQL, Redis, Kafka, Zookeeper                       |
  | 1     | Data Ingestion      | Kafka producer/consumer, IBM MQ, Clinical Gateway, Lab Processor |
  | 2     | Data Processing     | Spark (master/workers), streaming/batch jobs                     |
  | 3     | Feature Engineering | Feature stores (offline + online with Redis)                     |
  | 4     | ML Pipeline         | MLflow, ML training, model serving                               |
  | 5     | Observability       | Airflow, Prometheus, Grafana, OpenSearch/ELK                     |

  Command Structure

  Two command types:

  1. Information Commands (can be combined: -vhlo)
    - -v, --visualize - Show dashboard/visualization
    - -h, --health-check - Run health checks
    - -l, --logs - Tail recent logs
    - -o, --open - Show service URLs
    - -s, --summary - Show execution summary
    - -d, --stats - Show data statistics
  2. Management Commands (mutually exclusive - pick ONE)
    - --start - Start services via docker-compose up -d
    - --stop - Stop services + remove volumes via docker-compose down -v
    - --restart-rebuild - Full rebuild: stop → rebuild → start
    - --clean - Complete cleanup with confirmation

  Level Selection:
  - --level N (0-5) - Execute for level N and all dependencies below

  Command Rules

  ✅ VALID:
  --start --level 2              # Start levels 0,1,2
  --stop --level 0               # Stop level 0 only
  -vhlo --level 3                # Multiple info commands
  --start -vhs --level 1         # Management + info commands

  ❌ INVALID:
  --start --stop                 # Multiple management commands
  --restart-rebuild --clean      # Conflicting operations
  --start --stop --level 2       # Cannot combine management ops

  Key Behaviors

  Hierarchical execution: --level 3 automatically includes levels 0, 1, 2, 3

  Docker integration: Uses real docker-compose commands with profiles:
  - Level 0: No profile (always available)
  - Level 1: --profile data-ingestion
  - Level 2: --profile data-processing
  - Level 3: --profile features
  - Level 4: --profile ml-pipeline
  - Level 5: --profile observability

  Error handling: Validate mutual exclusivity before execution

  Implementation Requirements

  Create pipeline-manager.sh that:
  1. Parses combined flags correctly (e.g., -vhlo)
  2. Validates only ONE management command
  3. Executes hierarchically (level N includes 0 to N)
  4. Calls appropriate Docker Compose commands
  5. Provides color-coded output
  6. Handles errors gracefully

  ---
