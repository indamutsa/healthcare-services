#!/bin/bash
#
# Central Configuration - Level definitions, service mappings, and constants
# All pipeline levels and their dependencies are defined here
#

# Mark as loaded to prevent circular sourcing
export COMMON_CONFIG_LOADED=true

# --- Colors for output ---
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export CYAN='\033[0;36m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'  # No Color

# --- Level Definitions ---
# Each level has: services, profiles, names, and dependencies
declare -gA LEVEL_SERVICES
declare -gA LEVEL_SERVICE_NAMES
declare -gA LEVEL_SETUP_SERVICES  # One-time initialization containers
declare -gA LEVEL_PROFILES
declare -gA LEVEL_NAMES
declare -gA LEVEL_DEPENDENCIES

# Level 0: Infrastructure (foundation services)
# Note: minio-setup is a one-time init container, excluded from running count
# For Level 0, container names match service names
LEVEL_SERVICES[0]="minio postgres-mlflow postgres-airflow redis redis-insight zookeeper kafka kafka-ui"
LEVEL_SERVICE_NAMES[0]="minio postgres-mlflow postgres-airflow redis redis-insight zookeeper kafka kafka-ui"
LEVEL_SETUP_SERVICES[0]="minio-setup"  # One-time initialization containers
LEVEL_PROFILES[0]=""  # No profile - always available
LEVEL_NAMES[0]="Infrastructure"
LEVEL_DEPENDENCIES[0]=""  # No dependencies

# Level 1: Data Ingestion
# Note: LEVEL_SERVICES contains CONTAINER NAMES for status checks
# LEVEL_SERVICE_NAMES contains docker-compose SERVICE NAMES for start/stop
LEVEL_SERVICES[1]="kafka-producer kafka-consumer clinical-mq clinical-gateway lab-processor clinical-data-generator"
LEVEL_SERVICE_NAMES[1]="kafka-producer kafka-consumer clinical-mq clinical-data-gateway lab-results-processor clinical-data-generator"
LEVEL_PROFILES[1]="data-ingestion"
LEVEL_NAMES[1]="Data Ingestion"
LEVEL_DEPENDENCIES[1]="0"

# Level 2: Data Processing
LEVEL_SERVICES[2]="spark-master spark-worker spark-streaming spark-batch"
LEVEL_SERVICE_NAMES[2]="spark-master spark-worker spark-streaming spark-batch"
LEVEL_PROFILES[2]="data-processing"
LEVEL_NAMES[2]="Data Processing"
LEVEL_DEPENDENCIES[2]="0 1"

# Level 3: Feature Engineering
LEVEL_SERVICES[3]="feature-engineering"
LEVEL_SERVICE_NAMES[3]="feature-engineering"
LEVEL_PROFILES[3]="features"
LEVEL_NAMES[3]="Feature Engineering"
LEVEL_DEPENDENCIES[3]="0 1 2"

# Level 4: ML Pipeline
LEVEL_SERVICES[4]="mlflow-server model-serving"
LEVEL_SERVICE_NAMES[4]="mlflow-server model-serving"
LEVEL_PROFILES[4]="ml-pipeline"
LEVEL_NAMES[4]="ML Pipeline"
LEVEL_DEPENDENCIES[4]="0 1 2 3"

# Level 5: Orchestration (Airflow)
LEVEL_SERVICES[5]="airflow-init airflow-webserver airflow-scheduler"
LEVEL_SERVICE_NAMES[5]="postgres-airflow airflow-init airflow-webserver airflow-scheduler"
LEVEL_PROFILES[5]="orchestration"
LEVEL_NAMES[5]="Orchestration"
LEVEL_DEPENDENCIES[5]="0 1 2 3 4"

# Level 6: Observability
LEVEL_SERVICES[6]="prometheus grafana monitoring-service opensearch opensearch-dashboards data-prepper filebeat"
LEVEL_SERVICE_NAMES[6]="prometheus grafana monitoring-service opensearch opensearch-dashboards data-prepper filebeat"
LEVEL_PROFILES[6]="observability"
LEVEL_NAMES[6]="Observability"
LEVEL_DEPENDENCIES[6]="0 1 2 3 4 5"

# Maximum level number
export MAX_LEVEL=6

# --- MinIO Configuration ---
export MINIO_ENDPOINT="http://localhost:9000"
export MINIO_USER="minioadmin"
export MINIO_PASSWORD="minioadmin"
export MINIO_BUCKETS="clinical-mlops mlflow-artifacts dvc-storage"

# --- Database Configuration ---
export POSTGRES_MLFLOW_HOST="localhost"
export POSTGRES_MLFLOW_PORT="5432"
export POSTGRES_MLFLOW_USER="mlflow"
export POSTGRES_MLFLOW_DB="mlflow"
export MLFLOW_TRACKING_PORT="5050"

export POSTGRES_AIRFLOW_HOST="localhost"
export POSTGRES_AIRFLOW_PORT="5433"
export POSTGRES_AIRFLOW_USER="airflow"
export POSTGRES_AIRFLOW_DB="airflow"

# --- Kafka Configuration ---
export KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
export KAFKA_TOPICS="patient-vitals lab-results clinical-events"

# --- Redis Configuration ---
export REDIS_HOST="localhost"
export REDIS_PORT="6379"

# --- Timeouts and Retries ---
export DEFAULT_TIMEOUT=60  # seconds
export DEFAULT_RETRIES=5
export HEALTH_CHECK_INTERVAL=10  # seconds
