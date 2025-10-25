"""
MLflow logging operations.
"""

import mlflow
import mlflow.sklearn
import mlflow.xgboost
import mlflow.pytorch
import xgboost as xgb
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
        
        # Enable autologging (disabled for manual control of model logging)
        # We log models manually to have fine-grained control over signatures,
        # input examples, and custom artifacts
        if self.config['mlflow'].get('autolog', False):
            # Enable only metrics and parameters autologging
            mlflow.sklearn.autolog(log_models=False, silent=True)
            mlflow.xgboost.autolog(log_models=False, silent=True)
            mlflow.pytorch.autolog(log_models=False, silent=True)
    
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
        import numpy as np
        import matplotlib.pyplot as plt

        # Get coefficients
        coef = model.coef_[0]

        # Create dataframe with feature names if available
        if hasattr(model, 'feature_names_in_'):
            feature_names = model.feature_names_in_
        else:
            feature_names = [f"feature_{i}" for i in range(len(coef))]

        # Get top 20 features by absolute coefficient
        indices = np.argsort(np.abs(coef))[-20:]
        top_features = [feature_names[i] for i in indices]
        top_coef = coef[indices]

        # Create plot
        plt.figure(figsize=(10, 8))
        colors = ['red' if c < 0 else 'green' for c in top_coef]
        plt.barh(top_features, top_coef, color=colors)
        plt.xlabel('Coefficient Value')
        plt.title('Top 20 Feature Coefficients (Logistic Regression)')
        plt.tight_layout()
        plt.savefig('feature_importance.png', dpi=150, bbox_inches='tight')
        plt.close()

        mlflow.log_artifact('feature_importance.png', 'feature_importance')

        # Log as CSV
        df_importance = pd.DataFrame({
            'feature': feature_names,
            'coefficient': coef,
            'abs_coefficient': np.abs(coef)
        }).sort_values('abs_coefficient', ascending=False)

        df_importance.to_csv('feature_importance.csv', index=False)
        mlflow.log_artifact('feature_importance.csv', 'feature_importance')

        print(f"  ✓ Logged feature importance (top: {top_features[-1]})")

    def _log_tree_importance(self, model):
        """Log tree-based importance."""
        import numpy as np
        import matplotlib.pyplot as plt

        # Get feature importance
        importance = model.feature_importances_

        # Create dataframe with feature names if available
        if hasattr(model, 'feature_names_in_'):
            feature_names = model.feature_names_in_
        else:
            feature_names = [f"feature_{i}" for i in range(len(importance))]

        # Get top 20 features
        indices = np.argsort(importance)[-20:]
        top_features = [feature_names[i] for i in indices]
        top_importance = importance[indices]

        # Create plot
        plt.figure(figsize=(10, 8))
        plt.barh(top_features, top_importance, color='steelblue')
        plt.xlabel('Feature Importance')
        plt.title('Top 20 Feature Importance (Tree-based Model)')
        plt.tight_layout()
        plt.savefig('feature_importance.png', dpi=150, bbox_inches='tight')
        plt.close()

        mlflow.log_artifact('feature_importance.png', 'feature_importance')

        # Log as CSV
        df_importance = pd.DataFrame({
            'feature': feature_names,
            'importance': importance
        }).sort_values('importance', ascending=False)

        df_importance.to_csv('feature_importance.csv', index=False)
        mlflow.log_artifact('feature_importance.csv', 'feature_importance')

        print(f"  ✓ Logged feature importance (top: {top_features[-1]})")

    def _log_xgboost_feature_importance(self, model):
        """Log XGBoost importance."""
        import matplotlib.pyplot as plt

        # Get importance scores (gain)
        importance_dict = model.get_score(importance_type='gain')

        if not importance_dict:
            print("  ⚠ No feature importance available")
            return

        # Convert to sorted lists
        features = list(importance_dict.keys())
        importance = list(importance_dict.values())

        # Sort by importance
        sorted_idx = sorted(range(len(importance)), key=lambda i: importance[i], reverse=True)
        top_20_idx = sorted_idx[:20]

        top_features = [features[i] for i in top_20_idx]
        top_importance = [importance[i] for i in top_20_idx]

        # Create plot
        plt.figure(figsize=(10, 8))
        plt.barh(top_features[::-1], top_importance[::-1], color='orange')
        plt.xlabel('Gain')
        plt.title('Top 20 Feature Importance (XGBoost - Gain)')
        plt.tight_layout()
        plt.savefig('feature_importance.png', dpi=150, bbox_inches='tight')
        plt.close()

        mlflow.log_artifact('feature_importance.png', 'feature_importance')

        # Log as CSV
        df_importance = pd.DataFrame({
            'feature': features,
            'importance': importance
        }).sort_values('importance', ascending=False)

        df_importance.to_csv('feature_importance.csv', index=False)
        mlflow.log_artifact('feature_importance.csv', 'feature_importance')

        print(f"  ✓ Logged feature importance (top: {top_features[0]})")
    
    def log_ensemble_results(
        self, ensemble, individual_predictions, val_metrics, test_metrics, X_val, y_val
    ):
        """Log ensemble model results."""
        print(f"\n{'-'*60}")
        print("Logging: Ensemble Model")
        print(f"{'-'*60}")

        with mlflow.start_run(run_name="ensemble", nested=True):
            # Log ensemble configuration
            mlflow.set_tags({'model_type': 'ensemble', 'framework': 'sklearn'})
            mlflow.log_params({
                'ensemble_method': self.config['ensemble']['method'],
                'voting_type': self.config['ensemble']['voting_type'],
                'n_models': len(individual_predictions)
            })

            # Log metrics
            for metric_name, value in val_metrics.items():
                if isinstance(value, (int, float)):
                    mlflow.log_metric(f"val_{metric_name}", value)

            for metric_name, value in test_metrics.items():
                if isinstance(value, (int, float)):
                    mlflow.log_metric(f"test_{metric_name}", value)

            # Log individual model contributions
            import numpy as np
            y_val_pred = ensemble.predict(X_val) if hasattr(ensemble, 'predict') else \
                         ensemble.predict_proba(X_val)[:, 1]

            self._log_plots(y_val, y_val_pred, "Ensemble")

            # Log model diversity metrics
            self._log_model_diversity(individual_predictions, y_val)

            # Log ensemble model
            from mlflow.models.signature import infer_signature
            signature = infer_signature(X_val, y_val_pred)
            mlflow.sklearn.log_model(ensemble, "model", signature=signature, input_example=X_val[:5])

            print(f"✓ Ensemble - Val AUC: {val_metrics['roc_auc']:.4f}")

    def _log_model_diversity(self, individual_predictions, y_val):
        """Log diversity metrics for ensemble models."""
        import numpy as np
        from scipy.stats import pearsonr

        # Calculate pairwise correlations
        model_names = list(individual_predictions.keys())
        n_models = len(model_names)

        if n_models < 2:
            return

        correlation_matrix = np.zeros((n_models, n_models))

        for i, model_i in enumerate(model_names):
            for j, model_j in enumerate(model_names):
                if i == j:
                    correlation_matrix[i, j] = 1.0
                else:
                    corr, _ = pearsonr(
                        individual_predictions[model_i],
                        individual_predictions[model_j]
                    )
                    correlation_matrix[i, j] = corr

        # Log average correlation
        avg_corr = (correlation_matrix.sum() - n_models) / (n_models * (n_models - 1))
        mlflow.log_metric("model_avg_correlation", avg_corr)

        # Create heatmap
        import matplotlib.pyplot as plt
        import seaborn as sns

        plt.figure(figsize=(10, 8))
        sns.heatmap(
            correlation_matrix,
            annot=True,
            fmt='.3f',
            cmap='coolwarm',
            xticklabels=model_names,
            yticklabels=model_names,
            vmin=0, vmax=1,
            center=0.5
        )
        plt.title('Model Prediction Correlation Matrix')
        plt.tight_layout()
        plt.savefig('model_diversity.png', dpi=150, bbox_inches='tight')
        plt.close()

        mlflow.log_artifact('model_diversity.png', 'ensemble_analysis')

        print(f"  ✓ Logged model diversity (avg correlation: {avg_corr:.3f})")

    def log_cross_validation_results(self, cv_scores, model_name):
        """Log cross-validation results."""
        import numpy as np

        # Log mean and std of CV scores
        mlflow.log_metrics({
            'cv_mean_auc': np.mean(cv_scores),
            'cv_std_auc': np.std(cv_scores),
            'cv_min_auc': np.min(cv_scores),
            'cv_max_auc': np.max(cv_scores)
        })

        # Log individual fold scores
        for fold, score in enumerate(cv_scores):
            mlflow.log_metric(f'cv_fold_{fold}_auc', score)

        # Create CV visualization
        import matplotlib.pyplot as plt

        plt.figure(figsize=(10, 6))
        plt.bar(range(len(cv_scores)), cv_scores, color='steelblue', alpha=0.7)
        plt.axhline(y=np.mean(cv_scores), color='red', linestyle='--',
                   label=f'Mean: {np.mean(cv_scores):.4f}')
        plt.xlabel('Fold')
        plt.ylabel('AUC Score')
        plt.title(f'Cross-Validation Results - {model_name}')
        plt.legend()
        plt.tight_layout()
        plt.savefig('cv_results.png', dpi=150, bbox_inches='tight')
        plt.close()

        mlflow.log_artifact('cv_results.png', 'cross_validation')

        print(f"  ✓ Logged CV results (mean AUC: {np.mean(cv_scores):.4f} ± {np.std(cv_scores):.4f})")

    def log_data_quality_warnings(self, warnings: Dict):
        """Log data quality warnings and issues."""
        if not warnings:
            return

        # Log warnings as tags and metrics
        for warning_type, warning_data in warnings.items():
            if isinstance(warning_data, dict):
                # Log structured warnings
                for key, value in warning_data.items():
                    if isinstance(value, (int, float)):
                        mlflow.log_metric(f"data_quality_{warning_type}_{key}", value)
                    else:
                        mlflow.set_tag(f"data_quality_{warning_type}_{key}", str(value))
            else:
                # Log simple warnings
                mlflow.set_tag(f"data_quality_{warning_type}", str(warning_data))

        # Create warnings report
        report_lines = ["Data Quality Warnings Report", "=" * 60, ""]

        for warning_type, warning_data in warnings.items():
            report_lines.append(f"{warning_type}:")
            if isinstance(warning_data, dict):
                for key, value in warning_data.items():
                    report_lines.append(f"  - {key}: {value}")
            else:
                report_lines.append(f"  - {warning_data}")
            report_lines.append("")

        # Save and log report
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write('\n'.join(report_lines))
            warnings_file = f.name

        mlflow.log_artifact(warnings_file, "data_quality")
        os.unlink(warnings_file)

        print(f"  ✓ Logged {len(warnings)} data quality warnings")

    def _log_model(self, model, model_type, X_val):
        """Log model to MLflow."""
        from mlflow.models.signature import infer_signature

        if model_type == 'sklearn':
            signature = infer_signature(X_val, model.predict_proba(X_val))
            mlflow.sklearn.log_model(model, "model", signature=signature, input_example=X_val[:5])
