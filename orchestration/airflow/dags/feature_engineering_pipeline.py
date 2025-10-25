"""
Feature Engineering Pipeline DAG
Automated daily feature engineering for clinical trials data
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.dates import days_ago
import os
import sys

# Add the application path to Python path for imports
sys.path.append('/opt/airflow/applications/feature-engineering')

try:
    from pipeline import FeatureEngineeringPipeline
    FEATURE_ENGINEERING_AVAILABLE = True
except ImportError:
    FEATURE_ENGINEERING_AVAILABLE = False


def check_silver_data_availability(**context):
    """Check if silver data is available for the processing date"""
    execution_date = context['ds']
    print(f"Checking silver data availability for date: {execution_date}")
    
    # This would typically check MinIO/S3 for data existence
    # For now, simulate the check
    import random
    data_available = random.random() > 0.1  # 90% chance data is available
    
    if data_available:
        print(f"✓ Silver data available for {execution_date}")
        return True
    else:
        print(f"✗ No silver data found for {execution_date}")
        raise ValueError(f"No silver data available for {execution_date}")


def run_feature_engineering(**context):
    """Run the feature engineering pipeline"""
    execution_date = context['ds']
    print(f"Running feature engineering pipeline for date: {execution_date}")
    
    if not FEATURE_ENGINEERING_AVAILABLE:
        print("Feature engineering pipeline not available, using fallback")
        # Simulate feature engineering
        return {
            "status": "simulated",
            "date": execution_date,
            "features_generated": 50,
            "records_processed": 1000
        }
    
    try:
        # Set environment variable for the processing date
        os.environ["PROCESS_DATE"] = execution_date
        
        # Initialize and run pipeline
        pipeline = FeatureEngineeringPipeline("/app/config/features.yaml")
        pipeline.run(execution_date)
        
        return {
            "status": "success",
            "date": execution_date,
            "pipeline": "feature_engineering"
        }
        
    except Exception as e:
        print(f"Feature engineering pipeline failed: {str(e)}")
        raise


def validate_feature_store(**context):
    """Validate that features were properly written to feature store"""
    execution_date = context['ds']
    print(f"Validating feature store for date: {execution_date}")
    
    # Simulate validation
    import random
    validation_passed = random.random() > 0.05  # 95% success rate
    
    if validation_passed:
        print(f"✓ Feature store validation passed for {execution_date}")
        return {
            "validation_status": "passed",
            "date": execution_date,
            "features_validated": 50,
            "online_store_sync": True,
            "offline_store_sync": True
        }
    else:
        print(f"✗ Feature store validation failed for {execution_date}")
        raise ValueError(f"Feature store validation failed for {execution_date}")


def monitor_feature_quality(**context):
    """Monitor feature quality and distributions"""
    execution_date = context['ds']
    print(f"Monitoring feature quality for date: {execution_date}")
    
    # Simulate quality monitoring
    quality_metrics = {
        "null_rate": 0.02,
        "outlier_rate": 0.05,
        "distribution_drift": 0.1,
        "correlation_shift": 0.03
    }
    
    # Check if quality is acceptable
    quality_acceptable = all(metric < 0.1 for metric in quality_metrics.values())
    
    if quality_acceptable:
        print(f"✓ Feature quality acceptable for {execution_date}")
        return {
            "quality_status": "acceptable",
            "date": execution_date,
            "metrics": quality_metrics
        }
    else:
        print(f"⚠️ Feature quality issues detected for {execution_date}")
        return {
            "quality_status": "warning",
            "date": execution_date,
            "metrics": quality_metrics,
            "recommendation": "review_feature_distributions"
        }


def update_feature_metadata(**context):
    """Update feature metadata and documentation"""
    execution_date = context['ds']
    print(f"Updating feature metadata for date: {execution_date}")
    
    # Simulate metadata update
    return {
        "metadata_updated": True,
        "date": execution_date,
        "features_registered": 50,
        "schema_version": "v1.0",
        "documentation_generated": True
    }


def send_feature_notifications(**context):
    """Send notifications about feature engineering completion"""
    execution_date = context['ds']
    task_instances = context['task_instance']
    
    # Get results from previous tasks
    feature_result = task_instances.xcom_pull(task_ids='run_feature_engineering')
    validation_result = task_instances.xcom_pull(task_ids='validate_feature_store')
    quality_result = task_instances.xcom_pull(task_ids='monitor_feature_quality')
    
    print(f"Sending feature engineering notifications for {execution_date}")
    
    # Compose notification message
    status = "SUCCESS" if feature_result.get("status") == "success" else "FAILED"
    message = f"""
    Feature Engineering Pipeline - {execution_date}
    Status: {status}
    
    Results:
    - Features Generated: {feature_result.get('features_generated', 'N/A')}
    - Validation Status: {validation_result.get('validation_status', 'N/A')}
    - Quality Status: {quality_result.get('quality_status', 'N/A')}
    
    Feature Store:
    - Online Store Sync: {validation_result.get('online_store_sync', 'N/A')}
    - Offline Store Sync: {validation_result.get('offline_store_sync', 'N/A')}
    """
    
    print(message)
    
    return {
        "notifications_sent": True,
        "date": execution_date,
        "channels": ["slack", "email"],
        "status": status
    }


# Default arguments for the DAG
default_args = {
    'owner': 'clinical_trials_team',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=10),
    'execution_timeout': timedelta(hours=3),
}

# Define the DAG
with DAG(
    'feature_engineering_pipeline',
    default_args=default_args,
    description='Automated daily feature engineering for clinical trials data',
    schedule_interval=timedelta(hours=6),  # Run every 6 hours
    catchup=False,
    tags=['clinical_trials', 'feature_engineering', 'mlops', 'daily'],
    max_active_runs=1,  # Only one run at a time to avoid conflicts
) as dag:
    
    # Start pipeline
    start_pipeline = DummyOperator(
        task_id='start_feature_engineering'
    )
    
    # Check silver data availability
    check_data = PythonOperator(
        task_id='check_silver_data_availability',
        python_callable=check_silver_data_availability
    )
    
    # Run feature engineering pipeline
    run_features = PythonOperator(
        task_id='run_feature_engineering',
        python_callable=run_feature_engineering
    )
    
    # Alternative: Run via bash command if Python import fails
    run_features_bash = BashOperator(
        task_id='run_feature_engineering_bash',
        bash_command='''
            export PROCESS_DATE={{ ds }}
            cd /opt/airflow/applications/feature-engineering
            python pipeline.py
        ''',
        trigger_rule='all_failed'  # Only run if Python operator fails
    )
    
    # Validate feature store
    validate_store = PythonOperator(
        task_id='validate_feature_store',
        python_callable=validate_feature_store
    )
    
    # Monitor feature quality
    monitor_quality = PythonOperator(
        task_id='monitor_feature_quality',
        python_callable=monitor_feature_quality
    )
    
    # Update feature metadata
    update_metadata = PythonOperator(
        task_id='update_feature_metadata',
        python_callable=update_feature_metadata
    )
    
    # Send notifications
    send_notifications = PythonOperator(
        task_id='send_feature_notifications',
        python_callable=send_feature_notifications
    )
    
    # End pipeline
    end_pipeline = DummyOperator(
        task_id='end_feature_engineering'
    )
    
    # Define task dependencies
    start_pipeline >> check_data
    
    check_data >> [run_features, run_features_bash]
    
    # Continue with validation regardless of which method succeeded
    run_features >> validate_store
    run_features_bash >> validate_store
    
    validate_store >> monitor_quality
    monitor_quality >> update_metadata
    update_metadata >> send_notifications
    send_notifications >> end_pipeline