"""
Tests for Airflow DAGs in Clinical Trials MLOps Platform
"""

import unittest
from datetime import datetime, timedelta
import os
import sys

# Add the dags directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'dags'))

try:
    from airflow.models import DagBag
    AIRFLOW_AVAILABLE = True
except ImportError:
    AIRFLOW_AVAILABLE = False


class TestClinicalDAGs(unittest.TestCase):
    """Test clinical trials DAGs"""

    def setUp(self):
        """Set up test fixtures"""
        if AIRFLOW_AVAILABLE:
            self.dagbag = DagBag(
                dag_folder=os.path.join(os.path.dirname(__file__), '..', 'dags'),
                include_examples=False
            )

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_dagbag_import(self):
        """Test that DAGs can be imported without errors"""
        self.assertFalse(len(self.dagbag.import_errors), f"Import errors: {self.dagbag.import_errors}")

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_data_pipeline_dag_loaded(self):
        """Test that the clinical data pipeline DAG is loaded"""
        dag = self.dagbag.get_dag(dag_id='clinical_data_pipeline')
        self.assertIsNotNone(dag)
        self.assertEqual(len(dag.tasks), 11)  # Expected number of tasks

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_data_pipeline_dag_structure(self):
        """Test the structure of the clinical data pipeline DAG"""
        dag = self.dagbag.get_dag(dag_id='clinical_data_pipeline')

        # Check that required tasks exist
        required_tasks = [
            'start_pipeline',
            'validate_clinical_data',
            'monitor_kafka_topics',
            'spark_data_processing',
            'extract_features',
            'setup_mlflow_experiment',
            'train_model',
            'evaluate_model',
            'register_model',
            'deploy_model',
            'validate_data_quality',
            'end_pipeline'
        ]

        for task_id in required_tasks:
            self.assertIn(task_id, dag.task_dict, f"Task {task_id} not found in DAG")

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_dag_schedule(self):
        """Test DAG schedules are properly set"""
        dag = self.dagbag.get_dag(dag_id='clinical_data_pipeline')
        self.assertEqual(dag.schedule_interval, timedelta(hours=6))

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_dag_default_args(self):
        """Test DAG default arguments"""
        dag = self.dagbag.get_dag(dag_id='clinical_data_pipeline')

        required_default_args = ['owner', 'depends_on_past', 'start_date', 'email_on_failure']
        for arg in required_default_args:
            self.assertIn(arg, dag.default_args, f"Default arg {arg} missing")

    @unittest.skipUnless(AIRFLOW_AVAILABLE, "Airflow not available")
    def test_task_dependencies(self):
        """Test that task dependencies are correctly set"""
        dag = self.dagbag.get_dag(dag_id='clinical_data_pipeline')

        # Check specific dependencies
        start_task = dag.get_task('start_pipeline')
        validate_task = dag.get_task('validate_clinical_data')
        monitor_task = dag.get_task('monitor_kafka_topics')
        spark_task = dag.get_task('spark_data_processing')

        # start_pipeline should trigger both validate_data and monitor_kafka
        self.assertIn(validate_task, start_task.downstream_list)
        self.assertIn(monitor_task, start_task.downstream_list)

        # Both validate_data and monitor_kafka should trigger spark_data_processing
        self.assertIn(spark_task, validate_task.downstream_list)
        self.assertIn(spark_task, monitor_task.downstream_list)

    def test_dag_files_exist(self):
        """Test that all expected DAG files exist"""
        dag_dir = os.path.join(os.path.dirname(__file__), '..', 'dags')
        expected_dag_files = [
            'data_pipeline.py',
            'model_monitoring.py',
            'scheduled_retraining.py',
            'data_quality.py',
            'feature_backfill.py'
        ]

        for dag_file in expected_dag_files:
            file_path = os.path.join(dag_dir, dag_file)
            self.assertTrue(os.path.exists(file_path), f"DAG file {dag_file} does not exist")

    def test_plugin_files_exist(self):
        """Test that all expected plugin files exist"""
        plugin_dir = os.path.join(os.path.dirname(__file__), '..', 'plugins')
        expected_plugin_files = [
            '__init__.py',
            'mlflow_operator.py',
            'kubeflow_operator.py',
            'slack_notifier.py'
        ]

        for plugin_file in expected_plugin_files:
            file_path = os.path.join(plugin_dir, plugin_file)
            self.assertTrue(os.path.exists(file_path), f"Plugin file {plugin_file} does not exist")

    def test_plugin_subpackages_exist(self):
        """Test that plugin subpackages exist"""
        plugin_dir = os.path.join(os.path.dirname(__file__), '..', 'plugins')
        expected_subpackages = [
            'clinical_operators',
            'hooks',
            'sensors'
        ]

        for subpackage in expected_subpackages:
            subpackage_path = os.path.join(plugin_dir, subpackage)
            self.assertTrue(os.path.exists(subpackage_path), f"Plugin subpackage {subpackage} does not exist")

            # Check __init__.py exists
            init_file = os.path.join(subpackage_path, '__init__.py')
            self.assertTrue(os.path.exists(init_file), f"__init__.py missing in {subpackage}")


if __name__ == '__main__':
    unittest.main()