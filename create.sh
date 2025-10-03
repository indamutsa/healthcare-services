#!/bin/bash

# Script to create new MLOps folder structure
# This script only creates NEW directories and files
# It will NOT touch any existing files or directories

set -e

echo "🚀 Creating MLOps folder structure..."

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to create directory if it doesn't exist
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo -e "${GREEN}✓${NC} Created directory: ${BLUE}$1${NC}"
    else
        echo -e "${YELLOW}⊘${NC} Directory already exists: $1"
    fi
}

# Function to create file if it doesn't exist
create_file() {
    if [ ! -f "$1" ]; then
        touch "$1"
        echo -e "${GREEN}✓${NC} Created file: ${BLUE}$1${NC}"
    else
        echo -e "${YELLOW}⊘${NC} File already exists: $1"
    fi
}

# Function to create file with content if it doesn't exist
create_file_with_content() {
    if [ ! -f "$1" ]; then
        echo "$2" > "$1"
        echo -e "${GREEN}✓${NC} Created file with content: ${BLUE}$1${NC}"
    else
        echo -e "${YELLOW}⊘${NC} File already exists: $1"
    fi
}

echo ""
echo "📦 Creating Applications Structure..."

# Kafka Producer
create_dir "applications/kafka-producer"
create_dir "applications/kafka-producer/schemas"
create_file "applications/kafka-producer/Dockerfile"
create_file "applications/kafka-producer/requirements.txt"
create_file "applications/kafka-producer/producer.py"
create_file "applications/kafka-producer/data_generator.py"
create_file "applications/kafka-producer/schemas/vitals_schema.json"
create_file "applications/kafka-producer/schemas/labs_schema.json"
create_file "applications/kafka-producer/schemas/adverse_events_schema.json"

# Kafka Consumer
create_dir "applications/kafka-consumer"
create_dir "applications/kafka-consumer/config"
create_file "applications/kafka-consumer/Dockerfile"
create_file "applications/kafka-consumer/requirements.txt"
create_file "applications/kafka-consumer/consumer.py"
create_file "applications/kafka-consumer/s3_writer.py"
create_file "applications/kafka-consumer/config/consumer_config.yaml"

# Spark Processor
create_dir "applications/spark-processor"
create_dir "applications/spark-processor/jobs"
create_dir "applications/spark-processor/transformations"
create_dir "applications/spark-processor/utils"
create_file "applications/spark-processor/Dockerfile"
create_file "applications/spark-processor/requirements.txt"
create_file "applications/spark-processor/jobs/bronze_to_silver.py"
create_file "applications/spark-processor/jobs/silver_to_gold.py"
create_file "applications/spark-processor/jobs/data_quality_checks.py"
create_file "applications/spark-processor/transformations/deduplication.py"
create_file "applications/spark-processor/transformations/standardization.py"
create_file "applications/spark-processor/transformations/validation.py"
create_file "applications/spark-processor/utils/spark_session.py"

# Feature Engineering
create_dir "applications/feature-engineering"
create_dir "applications/feature-engineering/features"
create_dir "applications/feature-engineering/config"
create_file "applications/feature-engineering/Dockerfile"
create_file "applications/feature-engineering/requirements.txt"
create_file "applications/feature-engineering/pipeline.py"
create_file "applications/feature-engineering/feature_store.py"
create_file "applications/feature-engineering/features/temporal_features.py"
create_file "applications/feature-engineering/features/derived_features.py"
create_file "applications/feature-engineering/features/patient_context.py"
create_file "applications/feature-engineering/features/missingness_features.py"
create_file "applications/feature-engineering/config/features.yaml"

# ML Training
create_dir "applications/ml-training"
create_dir "applications/ml-training/models"
create_dir "applications/ml-training/utils"
create_dir "applications/ml-training/configs"
create_dir "applications/ml-training/notebooks"
create_file "applications/ml-training/Dockerfile"
create_file "applications/ml-training/requirements.txt"
create_file "applications/ml-training/train.py"
create_file "applications/ml-training/models/neural_net.py"
create_file "applications/ml-training/models/preprocessor.py"
create_file "applications/ml-training/models/ensemble.py"
create_file "applications/ml-training/utils/data_loader.py"
create_file "applications/ml-training/utils/early_stopping.py"
create_file "applications/ml-training/utils/metrics.py"
create_file "applications/ml-training/configs/model_config.yaml"
create_file "applications/ml-training/notebooks/model_exploration.ipynb"

# Model Serving
create_dir "applications/model-serving"
create_dir "applications/model-serving/models"
create_dir "applications/model-serving/middleware"
create_dir "applications/model-serving/schemas"
create_file "applications/model-serving/Dockerfile"
create_file "applications/model-serving/requirements.txt"
create_file "applications/model-serving/api.py"
create_file "applications/model-serving/predictor.py"
create_file "applications/model-serving/models/model_loader.py"
create_file "applications/model-serving/middleware/auth.py"
create_file "applications/model-serving/middleware/logging.py"
create_file "applications/model-serving/schemas/request.py"
create_file "applications/model-serving/schemas/response.py"

# Monitoring Service
create_dir "applications/monitoring-service"
create_dir "applications/monitoring-service/config"
create_file "applications/monitoring-service/Dockerfile"
create_file "applications/monitoring-service/requirements.txt"
create_file "applications/monitoring-service/drift_detector.py"
create_file "applications/monitoring-service/performance_monitor.py"
create_file "applications/monitoring-service/alerting.py"
create_file "applications/monitoring-service/config/thresholds.yaml"

echo ""
echo "🔄 Creating Orchestration Structure..."

# Airflow
create_dir "orchestration/airflow"
create_dir "orchestration/airflow/dags"
create_dir "orchestration/airflow/plugins"
create_dir "orchestration/airflow/config"
create_dir "orchestration/airflow/tests"
create_file "orchestration/airflow/Dockerfile"
create_file "orchestration/airflow/requirements.txt"
create_file "orchestration/airflow/dags/data_pipeline.py"
create_file "orchestration/airflow/dags/model_monitoring.py"
create_file "orchestration/airflow/dags/scheduled_retraining.py"
create_file "orchestration/airflow/dags/data_quality.py"
create_file "orchestration/airflow/dags/feature_backfill.py"
create_file "orchestration/airflow/plugins/kubeflow_operator.py"
create_file "orchestration/airflow/plugins/mlflow_operator.py"
create_file "orchestration/airflow/plugins/slack_notifier.py"
create_file "orchestration/airflow/config/airflow.cfg"
create_file "orchestration/airflow/config/connections.yaml"
create_file "orchestration/airflow/tests/test_dags.py"

# Kubeflow
create_dir "orchestration/kubeflow"
create_dir "orchestration/kubeflow/pipelines"
create_dir "orchestration/kubeflow/components"
create_dir "orchestration/kubeflow/config"
create_file "orchestration/kubeflow/pipelines/training_pipeline.py"
create_file "orchestration/kubeflow/pipelines/hpo_pipeline.py"
create_file "orchestration/kubeflow/pipelines/deployment_pipeline.py"
create_file "orchestration/kubeflow/pipelines/ab_test_pipeline.py"
create_file "orchestration/kubeflow/components/data_validation.py"
create_file "orchestration/kubeflow/components/feature_engineering.py"
create_file "orchestration/kubeflow/components/train_model.py"
create_file "orchestration/kubeflow/components/evaluate_model.py"
create_file "orchestration/kubeflow/components/register_model.py"
create_file "orchestration/kubeflow/components/deploy_model.py"
create_file "orchestration/kubeflow/config/pipeline_config.yaml"

echo ""
echo "⚙️  Enhancing Config Structure..."

# MLflow config
create_dir "config/mlflow"
create_file "config/mlflow/mlflow.env"
create_file "config/mlflow/tracking_server.yaml"

# Enhanced monitoring
create_dir "config/monitoring/rules"
create_file "config/monitoring/rules/system_rules.yml"
create_file "config/monitoring/rules/ml_model_rules.yml"

echo ""
echo "💾 Creating Data Structure..."

# Data directories
create_dir "data/raw"
create_dir "data/processed"
create_dir "data/features"
create_dir "data/models"
create_dir "data/artifacts"
create_file "data/raw/.gitkeep"
create_file "data/processed/.gitkeep"
create_file "data/features/.gitkeep"
create_file "data/models/.gitkeep"
create_file "data/artifacts/.gitkeep"

echo ""
echo "📚 Enhancing Documentation..."

# Architecture docs
create_file "docs/architecture/mlops_architecture.md"
create_file "docs/architecture/data_flow.md"
create_file "docs/architecture/model_lifecycle.md"

# Deployment docs
create_file "docs/deployment/airflow_setup.md"
create_file "docs/deployment/kubeflow_setup.md"
create_file "docs/deployment/mlflow_setup.md"

# Runbooks
create_dir "docs/runbooks"
create_file "docs/runbooks/model_retraining.md"
create_file "docs/runbooks/handling_drift.md"
create_file "docs/runbooks/incident_response.md"

echo ""
echo "🏗️  Creating Infrastructure..."

# Docker infrastructure
create_dir "infrastructure/docker/airflow"
create_dir "infrastructure/docker/kubeflow"
create_dir "infrastructure/docker/mlflow"
create_dir "infrastructure/docker/spark"
create_dir "infrastructure/docker/kafka"
create_file "infrastructure/docker/airflow/Dockerfile"
create_file "infrastructure/docker/kubeflow/Dockerfile"
create_file "infrastructure/docker/mlflow/Dockerfile"
create_file "infrastructure/docker/spark/Dockerfile"
create_file "infrastructure/docker/kafka/Dockerfile"

echo ""
echo "📊 Enhancing Monitoring..."

# Grafana dashboards
create_dir "monitoring/grafana/dashboards"
create_dir "monitoring/grafana/provisioning"
create_file "monitoring/grafana/dashboards/model_performance.json"
create_file "monitoring/grafana/dashboards/data_quality.json"
create_file "monitoring/grafana/dashboards/predictions.json"
create_file "monitoring/grafana/provisioning/datasources.yaml"
create_file "monitoring/grafana/provisioning/dashboards.yaml"

# Prometheus config
create_dir "monitoring/prometheus/alerts"
create_dir "monitoring/prometheus/targets"
create_file "monitoring/prometheus/alerts/infrastructure.yml"
create_file "monitoring/prometheus/alerts/ml_models.yml"
create_file "monitoring/prometheus/targets/ml_services.yml"

echo ""
echo "🔧 Creating Operations Structure..."

# DVC
create_dir "operations/dvc"
create_dir "operations/dvc/.dvc"
create_file "operations/dvc/.dvc/config"
create_file "operations/dvc/.dvcignore"
create_file "operations/dvc/dvc.yaml"
create_file "operations/dvc/params.yaml"

echo ""
echo "📝 Creating Scripts..."

# Setup scripts
create_dir "scripts/setup"
create_file "scripts/setup/init_mlflow.sh"
create_file "scripts/setup/init_dvc.sh"
create_file "scripts/setup/init_kafka.sh"
create_file "scripts/setup/init_airflow.sh"

# Data scripts
create_dir "scripts/data"
create_file "scripts/data/generate_test_data.sh"
create_file "scripts/data/ingest_historical_data.sh"
create_file "scripts/data/validate_data_quality.sh"

# ML scripts
create_dir "scripts/ml"
create_file "scripts/ml/trigger_training.sh"
create_file "scripts/ml/deploy_model.sh"
create_file "scripts/ml/rollback_model.sh"
create_file "scripts/ml/run_ab_test.sh"

echo ""
echo "🧪 Creating Test Structure..."

# Test directories
create_dir "tests/unit"
create_dir "tests/integration"
create_dir "tests/e2e"
create_file "tests/__init__.py"
create_file "tests/unit/__init__.py"
create_file "tests/unit/test_features.py"
create_file "tests/unit/test_model.py"
create_file "tests/unit/test_preprocessing.py"
create_file "tests/integration/__init__.py"
create_file "tests/integration/test_pipeline.py"
create_file "tests/integration/test_kafka_spark.py"
create_file "tests/integration/test_mlflow_integration.py"
create_file "tests/e2e/__init__.py"
create_file "tests/e2e/test_training_pipeline.py"
create_file "tests/e2e/test_serving_api.py"

echo ""
echo "📓 Creating Notebooks..."

create_dir "notebooks"
create_file "notebooks/01_data_exploration.ipynb"
create_file "notebooks/02_feature_analysis.ipynb"
create_file "notebooks/03_model_experimentation.ipynb"
create_file "notebooks/04_model_evaluation.ipynb"

echo ""
echo "🧪 Creating Test Data..."

# ML test scenarios
create_dir "test-data/ml-scenarios"
create_dir "test-data/ml-scenarios/drift_scenarios"
create_file "test-data/ml-scenarios/normal_patients.json"
create_file "test-data/ml-scenarios/adverse_events.json"
create_file "test-data/ml-scenarios/edge_cases.json"
create_file "test-data/ml-scenarios/drift_scenarios/feature_drift.json"
create_file "test-data/ml-scenarios/drift_scenarios/concept_drift.json"

echo ""
echo "🔄 Creating CI/CD Structure..."

# GitHub workflows
create_dir ".github/workflows"
create_file ".github/workflows/ci.yml"
create_file ".github/workflows/build-images.yml"
create_file ".github/workflows/deploy-staging.yml"
create_file ".github/workflows/deploy-production.yml"

echo ""
echo "📄 Creating Environment File..."

# Create .env template if it doesn't exist
ENV_FILE=".env.template"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << 'EOF'
# Kafka Configuration
KAFKA_BROKER=kafka:9092
KAFKA_ZOOKEEPER=zookeeper:2181

# S3 / MinIO Configuration
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=clinical-mlops

# MLflow Configuration
MLFLOW_TRACKING_URI=http://mlflow-server:5000
MLFLOW_BACKEND_STORE_URI=postgresql://mlflow:mlflow@mlflow-postgres:5432/mlflow
MLFLOW_ARTIFACT_ROOT=s3://clinical-mlops/mlflow

# Airflow Configuration
AIRFLOW__CORE__EXECUTOR=LocalExecutor
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql://airflow:airflow@airflow-postgres:5432/airflow
AIRFLOW__CORE__DAGS_FOLDER=/opt/airflow/dags
AIRFLOW__CORE__LOAD_EXAMPLES=False

# Model Serving
MODEL_SERVING_PORT=8000
MODEL_NAME=adverse-event-predictor
MODEL_VERSION=latest

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000

# Spark Configuration
SPARK_MASTER=spark://spark-master:7077
SPARK_WORKER_CORES=2
SPARK_WORKER_MEMORY=2g

# Postgres (shared)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=clinical_mlops
EOF
    echo -e "${GREEN}✓${NC} Created file: ${BLUE}$ENV_FILE${NC}"
else
    echo -e "${YELLOW}⊘${NC} File already exists: $ENV_FILE"
fi

echo ""
echo "📄 Creating .gitignore additions..."

# Create .gitignore.mlops with ML-specific ignores
GITIGNORE_MLOPS=".gitignore.mlops"
if [ ! -f "$GITIGNORE_MLOPS" ]; then
    cat > "$GITIGNORE_MLOPS" << 'EOF'
# ML-specific ignores (append to your existing .gitignore)

# Data files
data/raw/*
data/processed/*
data/features/*
data/models/*
data/artifacts/*
!data/**/.gitkeep

# MLflow
mlruns/
mlartifacts/

# DVC
*.dvc
.dvc/cache
.dvc/tmp

# Airflow
airflow/logs/
airflow/*.pid
airflow/*.log
airflow/*.db

# Notebooks
.ipynb_checkpoints/
notebooks/.ipynb_checkpoints/

# Python
*.pyc
__pycache__/
*.egg-info/
.pytest_cache/

# Environment
.env
*.env
!*.env.template

# Models
*.pth
*.pkl
*.h5
*.onnx

# Logs
*.log
logs/
EOF
    echo -e "${GREEN}✓${NC} Created file: ${BLUE}$GITIGNORE_MLOPS${NC}"
    echo -e "${YELLOW}📝 Note: Append contents of .gitignore.mlops to your .gitignore${NC}"
else
    echo -e "${YELLOW}⊘${NC} File already exists: $GITIGNORE_MLOPS"
fi

echo ""
echo "✅ Folder structure creation complete!"
echo ""
echo "📊 Summary:"
echo "  - Created applications for Kafka, Spark, ML training, and serving"
echo "  - Set up orchestration with Airflow and Kubeflow"
echo "  - Added data directories with .gitkeep files"
echo "  - Enhanced monitoring with ML-specific dashboards"
echo "  - Created test structure (unit, integration, e2e)"
echo "  - Added CI/CD workflows"
echo "  - Created environment template (.env.template)"
echo ""
echo "🔍 Next steps:"
echo "  1. Review .env.template and create your .env file"
echo "  2. Append .gitignore.mlops to your .gitignore"
echo "  3. Start implementing components in the applications/ directory"
echo "  4. Configure docker-compose.yml with new services"
echo ""