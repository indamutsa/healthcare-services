"""
MLflow Operator for Clinical Trials MLOps Pipeline
Handles experiment tracking, model registry operations, and model deployment
"""

import mlflow
import mlflow.sklearn
import mlflow.pyfunc
from mlflow.tracking import MlflowClient
import json
import logging
from typing import Dict, Any, Optional, List

# Conditional imports for Airflow
# These will work when Airflow is available in the environment
try:
    from airflow.models import BaseOperator
    from airflow.utils.decorators import apply_defaults
    from airflow.exceptions import AirflowException
    AIRFLOW_AVAILABLE = True
except ImportError:
    # Fallback for development/testing without Airflow
    class BaseOperator:
        def __init__(self, *args, **kwargs):
            self.log = logging.getLogger(__name__)
    
    def apply_defaults(func):
        return func
    
    class AirflowException(Exception):
        pass
    
    AIRFLOW_AVAILABLE = False


class MLflowCreateExperimentOperator(BaseOperator):
    """
    Creates a new MLflow experiment for tracking clinical trials model runs
    """
    
    @apply_defaults
    def __init__(
        self,
        experiment_name: str,
        mlflow_connection_id: str = "mlflow_default",
        tags: Optional[Dict[str, str]] = None,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.experiment_name = experiment_name
        self.mlflow_connection_id = mlflow_connection_id
        self.tags = tags or {}
    
    def execute(self, context):
        try:
            # Get MLflow connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                mlflow_conn = BaseHook.get_connection(self.mlflow_connection_id)
                mlflow.set_tracking_uri(mlflow_conn.get_uri())
            
            # Create experiment
            experiment = mlflow.get_experiment_by_name(self.experiment_name)
            if experiment is None:
                experiment_id = mlflow.create_experiment(
                    name=self.experiment_name,
                    tags=self.tags
                )
                self.log.info(f"Created MLflow experiment: {self.experiment_name} (ID: {experiment_id})")
            else:
                experiment_id = experiment.experiment_id
                self.log.info(f"MLflow experiment already exists: {self.experiment_name} (ID: {experiment_id})")
            
            return experiment_id
            
        except Exception as e:
            self.log.error(f"Failed to create MLflow experiment: {str(e)}")
            raise AirflowException(f"MLflow experiment creation failed: {str(e)}")


class MLflowLogModelOperator(BaseOperator):
    """
    Logs a trained model to MLflow with clinical trials specific metadata
    """
    
    @apply_defaults
    def __init__(
        self,
        experiment_name: str,
        run_name: str,
        model: Any,
        model_name: str,
        model_type: str,
        parameters: Dict[str, Any],
        metrics: Dict[str, float],
        artifacts: Optional[List[str]] = None,
        mlflow_connection_id: str = "mlflow_default",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.experiment_name = experiment_name
        self.run_name = run_name
        self.model = model
        self.model_name = model_name
        self.model_type = model_type
        self.parameters = parameters
        self.metrics = metrics
        self.artifacts = artifacts or []
        self.mlflow_connection_id = mlflow_connection_id
    
    def execute(self, context):
        try:
            # Get MLflow connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                mlflow_conn = BaseHook.get_connection(self.mlflow_connection_id)
                mlflow.set_tracking_uri(mlflow_conn.get_uri())
            
            # Set experiment
            mlflow.set_experiment(self.experiment_name)
            
            # Start MLflow run
            with mlflow.start_run(run_name=self.run_name) as run:
                # Log parameters
                mlflow.log_params(self.parameters)
                
                # Log metrics
                mlflow.log_metrics(self.metrics)
                
                # Log model based on type
                if self.model_type == "sklearn":
                    mlflow.sklearn.log_model(self.model, self.model_name)
                elif self.model_type == "pyfunc":
                    mlflow.pyfunc.log_model(self.model, self.model_name)
                else:
                    raise ValueError(f"Unsupported model type: {self.model_type}")
                
                # Log artifacts
                for artifact_path in self.artifacts:
                    mlflow.log_artifact(artifact_path)
                
                # Log clinical trials specific tags
                mlflow.set_tag("clinical_trials_model", "true")
                mlflow.set_tag("model_type", self.model_type)
                if AIRFLOW_AVAILABLE:
                    mlflow.set_tag("airflow_dag", context["dag"].dag_id)
                    mlflow.set_tag("airflow_run_id", context["run_id"])
                
                self.log.info(f"Successfully logged model to MLflow. Run ID: {run.info.run_id}")
                
                return run.info.run_id
                
        except Exception as e:
            self.log.error(f"Failed to log model to MLflow: {str(e)}")
            raise AirflowException(f"MLflow model logging failed: {str(e)}")


class MLflowRegisterModelOperator(BaseOperator):
    """
    Registers a model in MLflow Model Registry for deployment
    """
    
    @apply_defaults
    def __init__(
        self,
        run_id: str,
        model_name: str,
        model_path: str = "model",
        stage: str = "Staging",
        description: Optional[str] = None,
        mlflow_connection_id: str = "mlflow_default",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.run_id = run_id
        self.model_name = model_name
        self.model_path = model_path
        self.stage = stage
        self.description = description
        self.mlflow_connection_id = mlflow_connection_id
    
    def execute(self, context):
        try:
            # Get MLflow connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                mlflow_conn = BaseHook.get_connection(self.mlflow_connection_id)
                mlflow.set_tracking_uri(mlflow_conn.get_uri())
            
            # Create MLflow client
            client = MlflowClient()
            
            # Register model
            model_uri = f"runs:/{self.run_id}/{self.model_path}"
            
            # Check if model already exists
            try:
                registered_model = client.get_registered_model(self.model_name)
                self.log.info(f"Model {self.model_name} already exists in registry")
            except:
                # Create new registered model
                client.create_registered_model(self.model_name)
                self.log.info(f"Created new registered model: {self.model_name}")
            
            # Create new model version
            model_version = client.create_model_version(
                name=self.model_name,
                source=model_uri,
                run_id=self.run_id,
                description=self.description
            )
            
            # Transition to specified stage
            client.transition_model_version_stage(
                name=self.model_name,
                version=str(model_version.version),
                stage=self.stage
            )
            
            self.log.info(f"Successfully registered model {self.model_name} version {model_version.version} to {self.stage} stage")
            
            return {
                "model_name": self.model_name,
                "version": model_version.version,
                "stage": self.stage
            }
            
        except Exception as e:
            self.log.error(f"Failed to register model in MLflow: {str(e)}")
            raise AirflowException(f"MLflow model registration failed: {str(e)}")


class MLflowPromoteModelOperator(BaseOperator):
    """
    Promotes a model to Production stage based on validation metrics
    """
    
    @apply_defaults
    def __init__(
        self,
        model_name: str,
        version: int,
        target_stage: str = "Production",
        validation_metrics: Optional[Dict[str, float]] = None,
        mlflow_connection_id: str = "mlflow_default",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.model_name = model_name
        self.version = version
        self.target_stage = target_stage
        self.validation_metrics = validation_metrics or {}
        self.mlflow_connection_id = mlflow_connection_id
    
    def execute(self, context):
        try:
            # Get MLflow connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                mlflow_conn = BaseHook.get_connection(self.mlflow_connection_id)
                mlflow.set_tracking_uri(mlflow_conn.get_uri())
            
            # Create MLflow client
            client = MlflowClient()
            
            # Promote model to target stage
            client.transition_model_version_stage(
                name=self.model_name,
                version=str(self.version),
                stage=self.target_stage
            )
            
            # Log promotion metrics if provided
            if self.validation_metrics:
                with mlflow.start_run() as run:
                    mlflow.log_metrics(self.validation_metrics)
                    mlflow.set_tag("model_promotion", f"{self.model_name}_v{self.version}")
                    mlflow.set_tag("target_stage", self.target_stage)
            
            self.log.info(f"Successfully promoted {self.model_name} version {self.version} to {self.target_stage}")
            
            return {
                "model_name": self.model_name,
                "version": self.version,
                "stage": self.target_stage
            }
            
        except Exception as e:
            self.log.error(f"Failed to promote model in MLflow: {str(e)}")
            raise AirflowException(f"MLflow model promotion failed: {str(e)}")