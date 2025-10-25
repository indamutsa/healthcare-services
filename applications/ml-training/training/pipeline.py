"""
Training pipeline orchestrator.
"""

import mlflow
from datetime import datetime
from typing import Tuple

from utils.data_loader import FeatureStoreLoader
from models.preprocessor import DataPreprocessor
from .model_trainer import ModelTrainer
from .mlflow_logger import MLflowLogger


class TrainingPipeline:
    """Orchestrate multi-model training pipeline."""
    
    def __init__(self, config: dict):
        """
        Initialize pipeline.
        
        Args:
            config: Configuration dictionary
        """
        self.config = config
        self.logger = MLflowLogger(config)
        self.model_trainer = ModelTrainer(config, self.logger)
        
        # Storage
        self.preprocessor = None
        self.results = {}
        
        print(f"{'='*80}")
        print("CLINICAL ADVERSE EVENT PREDICTION - MULTI-MODEL TRAINING")
        print(f"{'='*80}")
    
    def run(self):
        """Execute complete training pipeline."""
        # Start parent MLflow run
        with mlflow.start_run(
            run_name=f"training_pipeline_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        ) as parent_run:
            
            # Setup experiment
            self.logger.setup_experiment()
            
            # Log pipeline metadata
            self.logger.log_pipeline_metadata(self.config)
            
            # 1. Load data
            X_train, X_val, X_test, y_train, y_val, y_test = self._load_data()
            
            # 2. Preprocess
            X_train, X_val, X_test = self._preprocess(X_train, X_val, X_test)
            
            # 3. Train models
            self.results = self.model_trainer.train_all_models(
                X_train, X_val, X_test, y_train, y_val, y_test
            )
            
            # 4. Log summary
            self.logger.log_training_summary(self.results)
            
            # 5. Register best model
            best_model_name, best_run_id = self._register_best_model()
            
            # Log to parent run
            mlflow.log_param("best_model", best_model_name)
            mlflow.log_param("best_model_run_id", best_run_id)
            mlflow.log_metric("best_val_auc", self.results[best_model_name]['roc_auc'])
            
            print(f"\n{'='*80}")
            print(f"✓ Training Pipeline Complete")
            print(f"  Parent Run ID: {parent_run.info.run_id}")
            print(f"  Best Model: {best_model_name}")
            print(f"{'='*80}")
    
    def _load_data(self) -> Tuple:
        """Load and split data."""
        print(f"\n{'='*60}")
        print("Loading Data")
        print(f"{'='*60}")

        loader = FeatureStoreLoader(self.config)

        # Load from feature store
        df = loader.load_data()
        X, y, timestamps, feature_names = loader.prepare_features(df)

        # Temporal split
        X_train, X_val, X_test, y_train, y_val, y_test = loader.temporal_split(
            X, y, timestamps
        )

        # Log dataset info to MLflow
        self.logger.log_dataset_info(X_train, y_train, X_val, y_val, X_test, y_test)

        # Log data quality warnings
        data_warnings = loader.get_data_quality_warnings()
        if data_warnings:
            self.logger.log_data_quality_warnings(data_warnings)

        loader.close()

        return X_train, X_val, X_test, y_train, y_val, y_test
    
    def _preprocess(self, X_train, X_val, X_test):
        """Preprocess features."""
        print(f"\n{'='*60}")
        print("Preprocessing Features")
        print(f"{'='*60}")
        
        self.preprocessor = DataPreprocessor(self.config)
        X_train, X_val, X_test = self.preprocessor.fit_transform(X_train, X_val, X_test)
        
        # Log preprocessor
        self.logger.log_preprocessor(self.preprocessor)
        
        return X_train, X_val, X_test
    
    def _register_best_model(self) -> Tuple[str, str]:
        """Register best model to registry."""
        # Find best model
        best_model_name = max(self.results, key=lambda x: self.results[x]['roc_auc'])
        
        # Register
        best_run_id = self.logger.register_model(
            best_model_name,
            self.results[best_model_name]['roc_auc']
        )
        
        return best_model_name, best_run_id