# Clinical Trials MLOps Orchestration

This directory contains the orchestration layer for the Clinical Trials MLOps pipeline, managing workflows across Airflow and Kubeflow for data processing, model training, and deployment.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐
│   Airflow DAGs  │    │  Kubeflow Pipelines │
│                 │    │                    │
│ • Data Pipeline │◄──►│ • Training Pipeline│
│ • Model Monitor │    │ • HPO Pipeline    │
│ • Data Quality  │    │ • Deployment Pipe │
│ • Retraining    │    │ • A/B Test Pipe   │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│           Custom Operators               │
│                                         │
│ • MLflowOperator    • SparkSubmitOperator│
│ • KubeflowOperator  • KafkaMonitorOperator│
└─────────────────────────────────────────┘
```

## Directory Structure

```
orchestration/
├── airflow/
│   ├── config/           # Airflow configuration files
│   ├── dags/            # Airflow DAG definitions
│   ├── plugins/         # Custom Airflow operators
│   ├── tests/           # Test suite for DAGs and operators
│   └── Dockerfile       # Airflow container definition
├── kubeflow/
│   ├── components/      # Reusable Kubeflow components
│   ├── pipelines/       # Kubeflow pipeline definitions
│   └── config/          # Kubeflow configuration
└── README.md           # This file
```

## Airflow Orchestration

### Core DAGs

1. **Clinical Data Pipeline** (`data_pipeline.py`)
   - End-to-end data processing and model training
   - Runs every 6 hours
   - Integrates with MLflow for experiment tracking

2. **Model Monitoring** (`model_monitoring.py`)
   - Monitors model performance and data drift
   - Triggers retraining when thresholds are exceeded
   - Runs every 12 hours

3. **Scheduled Retraining** (`scheduled_retraining.py`)
   - Periodic model retraining with new data
   - Runs weekly with full dataset

4. **Data Quality** (`data_quality.py`)
   - Validates data quality across the pipeline
   - Runs daily with comprehensive checks

5. **Feature Backfill** (`feature_backfill.py`)
   - Handles feature store updates and backfills
   - Runs on-demand for data corrections

### Custom Operators

#### MLflow Operators
- `MLflowCreateExperimentOperator`: Creates MLflow experiments
- `MLflowLogModelOperator`: Logs models with clinical trials metadata
- `MLflowRegisterModelOperator`: Registers models in MLflow Model Registry
- `MLflowPromoteModelOperator`: Promotes models to production

#### Spark Operators
- `SparkSubmitOperator`: Submits Spark jobs for data processing
- `SparkStreamingOperator`: Manages Spark Streaming jobs
- `SparkJobStatusSensor`: Monitors Spark job status

#### Kafka Operators
- `KafkaTopicMonitorOperator`: Monitors Kafka topic health
- `KafkaDataValidatorOperator`: Validates data quality in Kafka topics

### Configuration

Airflow configuration files:
- `config/airflow.cfg`: Main Airflow configuration
- `config/connections.yaml`: External service connections
- `config/pools.yaml`: Task execution pools
- `config/variables.yaml`: Pipeline variables and parameters

## Kubeflow Pipelines

### Core Pipelines

1. **Training Pipeline** (`training_pipeline.py`)
   - End-to-end model training with hyperparameter optimization
   - Integrates with MLflow for experiment tracking

2. **HPO Pipeline** (`hpo_pipeline.py`)
   - Hyperparameter optimization with Katib
   - Automated model selection and tuning

3. **Deployment Pipeline** (`deployment_pipeline.py`)
   - Model deployment to serving environments
   - A/B testing and canary deployments

4. **A/B Test Pipeline** (`ab_test_pipeline.py`)
   - Manages A/B testing experiments
   - Performance comparison and model selection

### Reusable Components

- `data_validation.py`: Data quality and validation checks
- `feature_engineering.py`: Feature extraction and transformation
- `train_model.py`: Model training with various algorithms
- `evaluate_model.py`: Model evaluation and metrics calculation
- `register_model.py`: Model registration in MLflow
- `deploy_model.py`: Model deployment to serving infrastructure

## Testing

### Test Structure

```
tests/
├── test_dags.py           # DAG validation and structure tests
├── test_operators.py      # Operator functionality tests
├── test_integration.py    # Integration tests
└── conftest.py           # Test configuration and fixtures
```

### Running Tests

```bash
# Run all tests
pytest orchestration/airflow/tests/

# Run specific test categories
pytest orchestration/airflow/tests/test_dags.py
pytest orchestration/airflow/tests/test_operators.py
```

## Deployment

### Airflow Deployment

1. **Build Airflow Image**:
   ```bash
   docker build -t clinical-trials-airflow orchestration/airflow/
   ```

2. **Start Airflow Services**:
   ```bash
   docker-compose up -d airflow-webserver airflow-scheduler
   ```

3. **Initialize Database**:
   ```bash
   docker-compose run airflow-webserver airflow db init
   ```

### Kubeflow Deployment

1. **Deploy Kubeflow Pipelines**:
   ```bash
   kubectl apply -f kubeflow/manifests/
   ```

2. **Upload Pipelines**:
   ```bash
   python orchestration/kubeflow/pipelines/deploy_pipelines.py
   ```

## Configuration Management

### Environment Variables

```bash
# MLflow Configuration
MLFLOW_TRACKING_URI=http://mlflow-server:5000
MLFLOW_EXPERIMENT_NAME=clinical_trials

# Spark Configuration
SPARK_MASTER=yarn
SPARK_DRIVER_MEMORY=2g

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
KAFKA_CLINICAL_TOPIC=clinical_data
```

### Connection Setup

Configure Airflow connections for:
- MLflow tracking server
- Spark cluster
- Kafka brokers
- Kubernetes cluster
- Database connections

## Monitoring and Logging

### Airflow Metrics
- DAG execution status and duration
- Task success/failure rates
- Resource utilization

### Pipeline Metrics
- Model training performance
- Data processing throughput
- Model inference latency

### Alerting
- DAG failures and retries
- Model performance degradation
- Data quality issues

## Development Workflow

1. **Add New DAGs**:
   - Create DAG file in `airflow/dags/`
   - Follow naming convention: `{purpose}_pipeline.py`
   - Include comprehensive documentation

2. **Create Custom Operators**:
   - Add operator class in `airflow/plugins/`
   - Implement proper error handling
   - Add unit tests

3. **Update Kubeflow Components**:
   - Modify components in `kubeflow/components/`
   - Update pipeline definitions
   - Test with sample data

4. **Testing**:
   - Write unit tests for new functionality
   - Run integration tests
   - Validate DAG structure

## Troubleshooting

### Common Issues

1. **DAG Import Errors**:
   - Check Python dependencies in requirements.txt
   - Verify custom operator imports
   - Ensure all modules are in Python path

2. **Operator Execution Failures**:
   - Check connection configurations
   - Verify external service availability
   - Review operator logs for specific errors

3. **Kubeflow Pipeline Failures**:
   - Check Kubernetes cluster health
   - Verify resource quotas and limits
   - Review component container logs

### Debugging Tools

- Airflow UI: DAG and task status monitoring
- Kubeflow Dashboard: Pipeline execution visualization
- MLflow UI: Experiment tracking and model registry
- Spark UI: Job monitoring and debugging

## Security Considerations

- Use Kubernetes secrets for sensitive configuration
- Implement proper RBAC for Airflow and Kubeflow
- Secure MLflow tracking server with authentication
- Encrypt data in transit between services
- Regular security scanning of container images

## Performance Optimization

### Airflow Optimization
- Use appropriate task pools for resource management
- Implement task timeouts and retry policies
- Optimize DAG structure for parallel execution

### Kubeflow Optimization
- Configure resource requests and limits
- Use appropriate node selectors and tolerations
- Implement pipeline caching for reusable components

### Spark Optimization
- Tune Spark configuration for clinical data volume
- Use appropriate partitioning strategies
- Implement data compression and serialization

## Contributing

1. Follow the established code style and patterns
2. Add comprehensive tests for new functionality
3. Update documentation for any changes
4. Validate DAGs and pipelines before deployment
5. Follow security best practices for new integrations