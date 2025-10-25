"""
Clinical Data Pipeline DAG
Main workflow for processing clinical trial data through the MLOps pipeline
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

# Import custom operators
try:
    from orchestration.airflow.plugins.kubeflow_operator import SparkSubmitOperator, SparkJobStatusSensor
    from orchestration.airflow.plugins.mlflow_operator import MLflowCreateExperimentOperator, MLflowLogModelOperator, MLflowRegisterModelOperator
    from orchestration.airflow.plugins.slack_notifier import KafkaTopicMonitorOperator, KafkaDataValidatorOperator
    CUSTOM_OPERATORS_AVAILABLE = True
except ImportError:
    try:
        # Fallback for direct import in container
        from plugins.kubeflow_operator import SparkSubmitOperator, SparkJobStatusSensor
        from plugins.mlflow_operator import MLflowCreateExperimentOperator, MLflowLogModelOperator, MLflowRegisterModelOperator
        from plugins.slack_notifier import KafkaTopicMonitorOperator, KafkaDataValidatorOperator
        CUSTOM_OPERATORS_AVAILABLE = True
    except ImportError:
        CUSTOM_OPERATORS_AVAILABLE = False


def validate_clinical_data():
    """Validate incoming clinical data"""
    print("Validating clinical data...")
    # Simulate validation logic
    return {"valid": True, "records_processed": 1000}


def extract_features():
    """Extract features from clinical data"""
    print("Extracting features from clinical data...")
    # Simulate feature extraction
    return {"features_extracted": 50, "feature_store_updated": True}


def train_model():
    """Train machine learning model"""
    print("Training machine learning model...")
    # Simulate model training
    return {"model_trained": True, "accuracy": 0.85}


def evaluate_model():
    """Evaluate model performance"""
    print("Evaluating model performance...")
    # Simulate model evaluation
    return {"evaluation_complete": True, "metrics": {"accuracy": 0.85, "precision": 0.82, "recall": 0.88}}


def deploy_model():
    """Deploy model to serving environment"""
    print("Deploying model to serving environment...")
    # Simulate model deployment
    return {"deployed": True, "model_version": "v1.0.0"}


# Default arguments for the DAG
default_args = {
    'owner': 'clinical_trials_team',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
with DAG(
    'clinical_data_pipeline',
    default_args=default_args,
    description='End-to-end clinical data processing and model training pipeline',
    schedule_interval=timedelta(hours=6),  # Run every 6 hours
    catchup=False,
    tags=['clinical_trials', 'mlops', 'data_pipeline'],
) as dag:
    
    # Start of pipeline
    start_pipeline = DummyOperator(
        task_id='start_pipeline'
    )
    
    # Data validation
    validate_data = PythonOperator(
        task_id='validate_clinical_data',
        python_callable=validate_clinical_data
    )
    
    # Kafka monitoring
    if CUSTOM_OPERATORS_AVAILABLE:
        monitor_kafka = KafkaTopicMonitorOperator(
            task_id='monitor_kafka_topics',
            kafka_connection_id='kafka_default',
            topics=['clinical_data', 'lab_results'],
            expected_message_rate=100
        )
    else:
        monitor_kafka = DummyOperator(
            task_id='monitor_kafka_topics'
        )
    
    # Spark data processing
    if CUSTOM_OPERATORS_AVAILABLE:
        spark_data_processing = SparkSubmitOperator(
            task_id='spark_data_processing',
            spark_app_path='/opt/airflow/dags/spark_jobs/clinical_data_processor.py',
            app_name='clinical_data_processor',
            app_args=['--date', '{{ ds }}']
        )
    else:
        spark_data_processing = DummyOperator(
            task_id='spark_data_processing'
        )
    
    # Feature engineering
    extract_features_task = PythonOperator(
        task_id='extract_features',
        python_callable=extract_features
    )
    
    # MLflow experiment setup
    if CUSTOM_OPERATORS_AVAILABLE:
        setup_mlflow_experiment = MLflowCreateExperimentOperator(
            task_id='setup_mlflow_experiment',
            experiment_name='clinical_trials_model_training',
            tags={'pipeline': 'clinical_data', 'version': '1.0'}
        )
    else:
        setup_mlflow_experiment = DummyOperator(
            task_id='setup_mlflow_experiment'
        )
    
    # Model training
    train_model_task = PythonOperator(
        task_id='train_model',
        python_callable=train_model
    )
    
    # Model evaluation
    evaluate_model_task = PythonOperator(
        task_id='evaluate_model',
        python_callable=evaluate_model
    )
    
    # Model registration (if custom operators available)
    if CUSTOM_OPERATORS_AVAILABLE:
        register_model = MLflowRegisterModelOperator(
            task_id='register_model',
            run_id='{{ task_instance.xcom_pull(task_ids=\"train_model\") }}',
            model_name='clinical_trials_prediction_model',
            stage='Staging',
            description='Clinical trials prediction model trained on patient data'
        )
    else:
        register_model = DummyOperator(
            task_id='register_model'
        )
    
    # Model deployment
    deploy_model_task = PythonOperator(
        task_id='deploy_model',
        python_callable=deploy_model
    )
    
    # Data quality validation
    if CUSTOM_OPERATORS_AVAILABLE:
        validate_data_quality = KafkaDataValidatorOperator(
            task_id='validate_data_quality',
            topic='clinical_data',
            sample_size=20
        )
    else:
        validate_data_quality = DummyOperator(
            task_id='validate_data_quality'
        )
    
    # End of pipeline
    end_pipeline = DummyOperator(
        task_id='end_pipeline'
    )
    
    # Define task dependencies
    start_pipeline >> [validate_data, monitor_kafka]
    
    validate_data >> spark_data_processing
    monitor_kafka >> spark_data_processing
    
    spark_data_processing >> extract_features_task
    
    extract_features_task >> setup_mlflow_experiment
    
    setup_mlflow_experiment >> train_model_task
    
    train_model_task >> evaluate_model_task
    
    evaluate_model_task >> register_model
    
    register_model >> deploy_model_task
    
    deploy_model_task >> validate_data_quality
    
    validate_data_quality >> end_pipeline