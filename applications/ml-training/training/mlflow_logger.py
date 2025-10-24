"""
MLflow logging operations.
"""

import mlflow
import mlflow.sklearn
import mlflow.xgboost
import mlflow.pytorch
import os
import pandas as pd
import tempfile
from typing import Dict
from utils.metrics import MetricsCalculator


class MLflowLogger:
    """Handle all MLflow logging operations."""
    
    def __init__(self, config: dict):
        """
        Initialize logger.
        
        Args:
            config: Configuration dictionary
        """
        self.config = config
    
    def setup_experiment(self):
        """Setup MLflow experiment."""
        mlflow.set_tracking_uri(self.config['mlflow']['tracking_uri'])
        
        # Create or get experiment
        experiment = mlflow.get_experiment_by_name(self.config['experiment']['name'])
        if experiment is None:
            mlflow.create_experiment(
                self.config['experiment']['name'],
                artifact_location=self.config['mlflow']['artifact_location'],
                tags=self.config['experiment']['tags']
            )
        
        mlflow.set_experiment(self.config['experiment']['name'])
        
        # Enable autologging
        if self.config['mlflow'].get('autolog', False):
            mlflow.autolog(
                log_input_examples=True,
                log_model_signatures=True,
                log_models=False,
                disable=False,
                silent=False
            )
    
    def log_pipeline_metadata(self, config: dict):
        """Log pipeline-level metadata."""
        mlflow.set_tags(config['experiment']['tags'])
        mlflow.log_params({
            'data_start_date': config['data']['start_date'],
            'data_end_date': config['data']['end_date'],
            'train_ratio': config['data']['split_ratios']['train'],
            'val_ratio': config['data']['split_ratios']['val'],
            'test_ratio': config['data']['split_ratios']['test']
        })
    
    def log_dataset_info(self, X_train, y_train, X_val, y_val, X_test, y_test):
        """Log dataset information."""
        dataset_info = {
            'train_samples': len(X_train),
            'train_positive_rate': float(y_train.mean()),
            'val_samples': len(X_val),
            'val_positive_rate': float(y_val.mean()),
            'test_samples': len(X_test),
            'test_positive_rate': float(y_test.mean()),
            'n_features': X_train.shape[1]
        }
        mlflow.log_params(dataset_info)
        
        # Log feature names
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write('\n'.join(X_train.columns.tolist()))
            feature_file = f.name
        mlflow.log_artifact(feature_file, "data_info")
        os.unlink(feature_file)
    
    def log_preprocessor(self, preprocessor):
        """Log preprocessor artifact."""
        os.makedirs('./artifacts', exist_ok=True)
        preprocessor_path = './artifacts/preprocessor.pkl'
        preprocessor.save(preprocessor_path)
        mlflow.log_artifact(preprocessor_path, "preprocessing")
        
        mlflow.log_params({
            'preprocessing_missing_strategy': self.config['preprocessing']['missing_strategy'],
            'preprocessing_scaler': self.config['preprocessing']['scaler']
        })
    
    def log_model_results(
        self, model, model_name, model_type, val_metrics, test_metrics, X_val, y_val
    ):
        """Log model results to MLflow."""
        # Log metrics
        for metric_name, value in val_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"val_{metric_name}", value)
        
        for metric_name, value in test_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"test_{metric_name}", value)
        
        # Log plots
        y_val_pred = model.predict_proba(X_val)[:, 1] if hasattr(model, 'predict_proba') else model.predict(X_val)
        self._log_plots(y_val, y_val_pred, model_name)
        
        # Log feature importance
        self._log_feature_importance(model, model_type)
        
        # Log model
        self._log_model(model, model_type, X_val)
    
    def log_xgboost_results(self, model, val_metrics, test_metrics, X_val, y_val):
        """Log XGBoost-specific results."""
        # Log metrics
        for metric_name, value in val_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"val_{metric_name}", value)
        
        for metric_name, value in test_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"test_{metric_name}", value)
        
        # Log plots
        y_val_pred = model.predict(xgb.DMatrix(X_val))
        self._log_plots(y_val, y_val_pred, "XGBoost")
        
        # Log feature importance
        self._log_xgboost_feature_importance(model)
        
        # Log model
        from mlflow.models.signature import infer_signature
        signature = infer_signature(X_val, y_val_pred)
        mlflow.xgboost.log_model(model, "model", signature=signature, input_example=X_val[:5])
    
    def log_pytorch_results(self, model, val_metrics, test_metrics, y_val, y_val_pred):
        """Log PyTorch-specific results."""
        # Log metrics
        for metric_name, value in val_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"val_{metric_name}", value)
        
        for metric_name, value in test_metrics.items():
            if isinstance(value, (int, float)):
                mlflow.log_metric(f"test_{metric_name}", value)
        
        # Log plots
        self._log_plots(y_val, y_val_pred, "Neural Network")
        
        # Log model
        mlflow.pytorch.log_model(model, "model", code_paths=["models/neural_net.py"])
    
    def log_training_history(self, evals_result):
        """Log XGBoost training history."""
        for i, (train_auc, val_auc) in enumerate(zip(
            evals_result['train']['auc'],
            evals_result['val']['auc']
        )):
            mlflow.log_metrics({
                'train_auc_iter': train_auc,
                'val_auc_iter': val_auc
            }, step=i)
    
    def log_nn_training_history(self, history):
        """Log neural network training history."""
        for epoch, (train_loss, val_loss, val_auc) in enumerate(zip(
            history['train_loss'],
            history['val_loss'],
            history['val_auc']
        )):
            mlflow.log_metrics({
                'train_loss': train_loss,
                'val_loss': val_loss,
                'val_auc': val_auc
            }, step=epoch)
    
    def log_training_summary(self, results: Dict):
        """Log training summary."""
        # Create comparison table
        df_results = pd.DataFrame(results).T
        df_results = df_results[['roc_auc', 'pr_auc', 'sensitivity', 'specificity', 'f1_score']]
        df_results = df_results.round(4)
        
        # Save and log
        os.makedirs('./artifacts', exist_ok=True)
        comparison_path = './artifacts/model_comparison.csv'
        df_results.to_csv(comparison_path)
        mlflow.log_artifact(comparison_path, "summary")
        
        print(f"\n{'='*80}")
        print("TRAINING SUMMARY")
        print(f"{'='*80}\n")
        print(df_results.to_string())
    
    def register_model(self, model_name: str, val_auc: float) -> str:
        """Register model to MLflow Model Registry."""
        print(f"\n{'='*80}")
        print(f"Registering Best Model: {model_name}")
        print(f"{'='*80}")
        
        # Find run ID
        experiment = mlflow.get_experiment_by_name(self.config['experiment']['name'])
        runs = mlflow.search_runs(
            experiment_ids=[experiment.experiment_id],
            filter_string=f"tags.mlflow.runName = '{model_name}'",
            order_by=["start_time DESC"],
            max_results=1
        )
        
        if len(runs) > 0:
            run_id = runs.iloc[0].run_id
            model_uri = f"runs:/{run_id}/model"
            registry_name = self.config['training']['model_registry_name']
            
            try:
                model_version = mlflow.register_model(
                    model_uri=model_uri,
                    name=registry_name,
                    tags={"model_type": model_name, "val_auc": str(val_auc)}
                )
                print(f"✓ Model registered: {registry_name} v{model_version.version}")
                return run_id
            except Exception as e:
                print(f"⚠ Registration failed: {e}")
                return run_id
        
        return None
    
    def _log_plots(self, y_true, y_pred, model_name):
        """Log evaluation plots."""
        MetricsCalculator.plot_roc_curve(y_true, y_pred, model_name, "roc_curve.png")
        mlflow.log_artifact("roc_curve.png", "plots")
        
        MetricsCalculator.plot_precision_recall_curve(y_true, y_pred, model_name, "pr_curve.png")
        mlflow.log_artifact("pr_curve.png", "plots")
        
        y_pred_binary = (y_pred >= 0.5).astype(int)
        MetricsCalculator.plot_confusion_matrix(y_true, y_pred_binary, "confusion_matrix.png")
        mlflow.log_artifact("confusion_matrix.png", "plots")
    
    def _log_feature_importance(self, model, model_type):
        """Log feature importance."""
        if model_type == 'sklearn':
            if hasattr(model, 'coef_'):
                self._log_lr_importance(model)
            elif hasattr(model, 'feature_importances_'):
                self._log_tree_importance(model)
    
    def _log_lr_importance(self, model):
        """Log logistic regression coefficients."""
        # Implementation here (as before)
        pass
    
    def _log_tree_importance(self, model):
        """Log tree-based importance."""
        # Implementation here (as before)
        pass
    
    def _log_xgboost_feature_importance(self, model):
        """Log XGBoost importance."""
        # Implementation here (as before)
        pass
    
    def _log_model(self, model, model_type, X_val):
        """Log model to MLflow."""
        from mlflow.models.signature import infer_signature
        
        if model_type == 'sklearn':
            signature = infer_signature(X_val, model.predict_proba(X_val))
            mlflow.sklearn.log_model(model, "model", signature=signature, input_example=X_val[:5])