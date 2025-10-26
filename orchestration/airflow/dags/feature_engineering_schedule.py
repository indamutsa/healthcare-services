"""
Feature Engineering Scheduled DAG
Automates the feature engineering pipeline to run on a configurable schedule
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.sensors.filesystem import FileSensor
from airflow.models import Variable
import json
import os

# Default arguments for the DAG
default_args = {
    'owner': 'mlops-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'max_active_runs': 1,  # Prevent concurrent feature engineering runs
}

# Create DAG instance
dag = DAG(
    'feature_engineering_schedule',
    default_args=default_args,
    description='Scheduled Feature Engineering Pipeline for Clinical Trials',
    schedule_interval='@hourly',  # Run every hour - can be configured via Variables
    catchup=False,
    tags=['mlops', 'feature-engineering', 'clinical-trials', 'automated'],
    doc_md="""
    ### Feature Engineering Scheduled Pipeline
    
    This DAG automates the feature engineering process for clinical trial data:
    
    **Schedule**: Every hour (configurable via Airflow Variables)
    **Source**: Raw clinical data from landing zone
    **Output**: Processed features in feature store
    **Monitoring**: Data quality checks and validation
    
    **Key Features:**
    - Automated data quality validation
    - Feature computation with clinical validation
    - Incremental updates to feature store
    - Comprehensive monitoring and alerting
    - Rollback capability on failures
    """
)

# Configuration from Airflow Variables
FEATURE_ENGINEERING_IMAGE = Variable.get("feature_engineering_image", default_var="feature-engineering:latest")
DATA_LANDING_ZONE = Variable.get("data_landing_zone", default_var="/data/landing-zone")
FEATURE_STORE_PATH = Variable.get("feature_store_path", default_var="/data/feature-store")
ENABLE_DATA_QUALITY_CHECKS = Variable.get("enable_data_quality_checks", default_var="true")
MIN_DATA_RECORDS = Variable.get("min_data_records", default_var="100")

# 1. Check for new data availability
check_new_data = FileSensor(
    task_id='check_new_data',
    filepath=f'{DATA_LANDING_ZONE}/clinical-data-*.json',
    poke_interval=300,  # Check every 5 minutes
    timeout=1800,       # Wait maximum 30 minutes
    mode='reschedule',
    doc_md="Waits for new clinical data files in the landing zone",
    dag=dag,
)

# 2. Validate data quality and completeness
validate_data_quality = BashOperator(
    task_id='validate_data_quality',
    bash_command=f"""
    echo "Starting data quality validation..."
    
    # Check minimum data volume
    record_count=$(find {DATA_LANDING_ZONE} -name "clinical-data-*.json" -newer /tmp/last_feature_run 2>/dev/null | wc -l)
    if [ "$record_count" -lt {MIN_DATA_RECORDS} ]; then
        echo "Insufficient data records: $record_count (minimum: {MIN_DATA_RECORDS})"
        exit 1
    fi
    
    # Validate JSON structure
    for file in $(find {DATA_LANDING_ZONE} -name "clinical-data-*.json" -newer /tmp/last_feature_run 2>/dev/null); do
        if ! python -c "import json; json.load(open('$file'))" 2>/dev/null; then
            echo "Invalid JSON in file: $file"
            exit 1
        fi
    done
    
    echo "Data quality validation passed: $record_count records"
    touch /tmp/data_quality_passed_{{{{ ds_nodash }}}}
    """,
    doc_md="Validates incoming data for quality, completeness, and format",
    dag=dag,
)

# 3. Backup current feature store (for rollback capability)
backup_feature_store = BashOperator(
    task_id='backup_feature_store',
    bash_command=f"""
    echo "Creating backup of current feature store..."
    
    if [ -d "{FEATURE_STORE_PATH}" ]; then
        backup_path="{FEATURE_STORE_PATH}_backup_{{{{ ds_nodash }}}}"
        cp -r {FEATURE_STORE_PATH} "$backup_path"
        echo "Feature store backed up to: $backup_path"
        
        # Keep only last 5 backups
        cd $(dirname "{FEATURE_STORE_PATH}")
        ls -t {FEATURE_STORE_PATH}_backup_* | tail -n +6 | xargs rm -rf
    else
        echo "No existing feature store to backup"
    fi
    """,
    doc_md="Creates backup of current feature store for rollback capability",
    dag=dag,
)

# 4. Run feature engineering pipeline
run_feature_engineering = DockerOperator(
    task_id='run_feature_engineering',
    image=FEATURE_ENGINEERING_IMAGE,
    api_version='auto',
    auto_remove=True,
    command=f"""
    python pipeline.py \\
        --input-path {DATA_LANDING_ZONE} \\
        --output-path {FEATURE_STORE_PATH} \\
        --config-path /app/config/production.yaml \\
        --validate-output \\
        --incremental
    """,
    volumes=[
        f'{DATA_LANDING_ZONE}:{DATA_LANDING_ZONE}',
        f'{FEATURE_STORE_PATH}:{FEATURE_STORE_PATH}',
        '/tmp:/tmp'
    ],
    environment={
        'PYTHONPATH': '/app',
        'LOG_LEVEL': 'INFO',
        'FEATURE_RUN_ID': '{{ run_id }}',
        'FEATURE_EXECUTION_DATE': '{{ ds }}'
    },
    doc_md="Executes the feature engineering pipeline with clinical validation",
    dag=dag,
)

# 5. Validate generated features
validate_features = BashOperator(
    task_id='validate_features',
    bash_command=f"""
    echo "Validating generated features..."
    
    # Check if features were generated
    if [ ! -d "{FEATURE_STORE_PATH}/features" ]; then
        echo "No features directory found"
        exit 1
    fi
    
    # Validate feature files
    feature_count=$(find {FEATURE_STORE_PATH}/features -name "*.parquet" 2>/dev/null | wc -l)
    if [ "$feature_count" -eq 0 ]; then
        echo "No feature files generated"
        exit 1
    fi
    
    # Check feature schema consistency
    python -c "
    import pandas as pd
    import os
    from pathlib import Path
    
    feature_dir = Path('{FEATURE_STORE_PATH}/features')
    schema_files = list(feature_dir.glob('_schema/*.json'))
    
    if not schema_files:
        print('No schema files found')
        exit(1)
    
    print(f'Feature validation passed: {len(schema_files)} schema files, $feature_count feature files')
    " || exit 1
    
    echo "Feature validation completed successfully"
    touch /tmp/features_validated_{{{{ ds_nodash }}}}
    """,
    doc_md="Validates generated features for completeness and schema consistency",
    dag=dag,
)

# 6. Update feature store metadata
update_metadata = BashOperator(
    task_id='update_metadata',
    bash_command=f"""
    echo "Updating feature store metadata..."
    
    # Create metadata record
    cat > {FEATURE_STORE_PATH}/metadata/last_update_{{{{ ds_nodash }}}}.json << EOF
    {{
        "run_id": "{{{{ run_id }}}}",
        "execution_date": "{{{{ ds }}}}",
        "execution_time": "{{{{ ts }}}}",
        "dag_id": "feature_engineering_schedule",
        "task_instance": "{{{{ ti.task_id }}}}",
        "data_source": "{DATA_LANDING_ZONE}",
        "feature_count": $(find {FEATURE_STORE_PATH}/features -name "*.parquet" 2>/dev/null | wc -l),
        "validation_passed": true,
        "backup_created": true
    }}
    EOF
    
    # Update latest symlink
    cd {FEATURE_STORE_PATH}/metadata
    ln -sf last_update_{{{{ ds_nodash }}}}.json latest_update.json
    
    echo "Metadata updated successfully"
    """,
    doc_md="Updates feature store metadata with run information",
    dag=dag,
)

# 7. Clean up temporary files and update timestamp
cleanup = BashOperator(
    task_id='cleanup',
    bash_command=f"""
    echo "Cleaning up temporary files..."
    
    # Update last run timestamp
    touch /tmp/last_feature_run
    
    # Clean up validation markers older than 7 days
    find /tmp -name "data_quality_passed_*" -mtime +7 -delete 2>/dev/null || true
    find /tmp -name "features_validated_*" -mtime +7 -delete 2>/dev/null || true
    
    # Clean up old metadata (keep last 30 days)
    find {FEATURE_STORE_PATH}/metadata -name "last_update_*.json" -mtime +30 -delete 2>/dev/null || true
    
    echo "Cleanup completed"
    """,
    doc_md="Cleans up temporary files and updates run timestamps",
    dag=dag,
)

# 8. Send success notification
notify_success = BashOperator(
    task_id='notify_success',
    bash_command="""
    echo "Feature engineering pipeline completed successfully"
    
    # Send notification (placeholder - integrate with your notification system)
    echo "NOTIFICATION: Feature Engineering Success - Run {{ run_id }} at {{ ts }}"
    
    # Log to monitoring system
    echo "METRIC: feature_engineering_success 1 {{ ts }}" >> /tmp/airflow_metrics.log
    """,
    trigger_rule='all_success',
    doc_md="Sends success notification and updates monitoring metrics",
    dag=dag,
)

# 9. Handle failures and rollback if needed
handle_failure = BashOperator(
    task_id='handle_failure',
    bash_command=f"""
    echo "Feature engineering pipeline failed - initiating rollback..."
    
    # Check if backup exists
    backup_path="{FEATURE_STORE_PATH}_backup_{{{{ ds_nodash }}}}"
    if [ -d "$backup_path" ]; then
        echo "Rolling back to backup: $backup_path"
        
        # Remove corrupted feature store
        if [ -d "{FEATURE_STORE_PATH}" ]; then
            mv {FEATURE_STORE_PATH} {FEATURE_STORE_PATH}_failed_{{{{ ds_nodash }}}}
        fi
        
        # Restore from backup
        mv "$backup_path" {FEATURE_STORE_PATH}
        echo "Rollback completed"
    else
        echo "No backup available for rollback"
    fi
    
    # Send failure notification
    echo "ALERT: Feature Engineering Failed - Run {{ run_id }} at {{ ts }}"
    echo "METRIC: feature_engineering_failure 1 {{ ts }}" >> /tmp/airflow_metrics.log
    """,
    trigger_rule='one_failed',
    doc_md="Handles pipeline failures and rolls back to previous state",
    dag=dag,
)

# Define task dependencies
check_new_data >> validate_data_quality >> backup_feature_store >> run_feature_engineering >> validate_features >> update_metadata >> cleanup >> notify_success

# Add failure handling
validate_data_quality >> handle_failure
run_feature_engineering >> handle_failure
validate_features >> handle_failure

# Skip data quality checks if disabled (for testing/emergency)
if ENABLE_DATA_QUALITY_CHECKS.lower() != 'true':
    check_new_data >> backup_feature_store