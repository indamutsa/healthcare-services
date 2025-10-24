"""
Individual model training.
"""

import mlflow
import mlflow.sklearn
import mlflow.xgboost
import mlflow.pytorch
import xgboost as xgb
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from typing import Dict

from models.neural_net import NeuralNetworkTrainer
from .evaluator import ModelEvaluator


class ModelTrainer:
    """Train individual models."""
    
    def __init__(self, config: dict, logger):
        """
        Initialize trainer.
        
        Args:
            config: Configuration dictionary
            logger: MLflow logger instance
        """
        self.config = config
        self.logger = logger
        self.evaluator = ModelEvaluator()
        self.results = {}
    
    def train_all_models(
        self, X_train, X_val, X_test, y_train, y_val, y_test
    ) -> Dict:
        """
        Train all enabled models.
        
        Returns:
            Dictionary of results per model
        """
        print(f"\n{'='*80}")
        print("TRAINING INDIVIDUAL MODELS")
        print(f"{'='*80}")
        
        # Train each enabled model
        if self.config['models']['logistic_regression']['enabled']:
            self._train_logistic_regression(
                X_train, X_val, X_test, y_train, y_val, y_test
            )
        
        if self.config['models']['random_forest']['enabled']:
            self._train_random_forest(
                X_train, X_val, X_test, y_train, y_val, y_test
            )
        
        if self.config['models']['xgboost']['enabled']:
            self._train_xgboost(
                X_train, X_val, X_test, y_train, y_val, y_test
            )
        
        if self.config['models']['neural_network']['enabled']:
            self._train_neural_network(
                X_train, X_val, X_test, y_train, y_val, y_test
            )
        
        return self.results
    
    def _train_logistic_regression(
        self, X_train, X_val, X_test, y_train, y_val, y_test
    ):
        """Train logistic regression."""
        print(f"\n{'-'*60}")
        print("Training: Logistic Regression")
        print(f"{'-'*60}")
        
        with mlflow.start_run(run_name="logistic_regression", nested=True):
            # Get parameters
            params = self.config['models']['logistic_regression']['params']
            
            # Log parameters and tags
            mlflow.log_params(params)
            mlflow.set_tags({'model_type': 'logistic_regression', 'framework': 'sklearn'})
            
            # Train
            model = LogisticRegression(**params)
            model.fit(X_train, y_train)
            
            # Evaluate
            val_metrics, test_metrics = self.evaluator.evaluate(
                model, X_val, y_val, X_test, y_test
            )
            
            # Log everything to MLflow
            self.logger.log_model_results(
                model=model,
                model_name="Logistic Regression",
                model_type='sklearn',
                val_metrics=val_metrics,
                test_metrics=test_metrics,
                X_val=X_val,
                y_val=y_val
            )
            
            # Store results
            self.results['logistic_regression'] = val_metrics
            
            print(f"✓ Logistic Regression - Val AUC: {val_metrics['roc_auc']:.4f}")
    
    def _train_random_forest(
        self, X_train, X_val, X_test, y_train, y_val, y_test
    ):
        """Train random forest."""
        print(f"\n{'-'*60}")
        print("Training: Random Forest")
        print(f"{'-'*60}")
        
        with mlflow.start_run(run_name="random_forest", nested=True):
            # Get parameters
            params = self.config['models']['random_forest']['params']
            
            # Log parameters and tags
            mlflow.log_params(params)
            mlflow.set_tags({'model_type': 'random_forest', 'framework': 'sklearn'})
            
            # Train
            model = RandomForestClassifier(**params)
            model.fit(X_train, y_train)
            
            # Evaluate
            val_metrics, test_metrics = self.evaluator.evaluate(
                model, X_val, y_val, X_test, y_test
            )
            
            # Log everything to MLflow
            self.logger.log_model_results(
                model=model,
                model_name="Random Forest",
                model_type='sklearn',
                val_metrics=val_metrics,
                test_metrics=test_metrics,
                X_val=X_val,
                y_val=y_val
            )
            
            # Store results
            self.results['random_forest'] = val_metrics
            
            print(f"✓ Random Forest - Val AUC: {val_metrics['roc_auc']:.4f}")
    
    def _train_xgboost(
        self, X_train, X_val, X_test, y_train, y_val, y_test
    ):
        """Train XGBoost."""
        print(f"\n{'-'*60}")
        print("Training: XGBoost")
        print(f"{'-'*60}")
        
        with mlflow.start_run(run_name="xgboost", nested=True):
            # Get parameters
            params = self.config['models']['xgboost']['params'].copy()
            n_estimators = params.pop('n_estimators')
            seed = params.pop('seed')
            
            # Log parameters and tags
            mlflow.log_params({**params, 'n_estimators': n_estimators, 'seed': seed})
            mlflow.set_tags({'model_type': 'xgboost', 'framework': 'xgboost'})
            
            # Create DMatrix
            dtrain = xgb.DMatrix(X_train, label=y_train)
            dval = xgb.DMatrix(X_val, label=y_val)
            dtest = xgb.DMatrix(X_test, label=y_test)
            
            # Train with evaluation
            evals_result = {}
            evals = [(dtrain, 'train'), (dval, 'val')]
            
            model = xgb.train(
                params=params,
                dtrain=dtrain,
                num_boost_round=n_estimators,
                evals=evals,
                early_stopping_rounds=self.config['models']['xgboost']['early_stopping']['rounds'],
                evals_result=evals_result,
                verbose_eval=False
            )
            
            # Log training history
            self.logger.log_training_history(evals_result)
            
            # Evaluate
            y_val_pred = model.predict(dval)
            y_test_pred = model.predict(dtest)
            val_metrics, test_metrics = self.evaluator.evaluate_predictions(
                y_val, y_val_pred, y_test, y_test_pred
            )
            
            # Log everything to MLflow
            self.logger.log_xgboost_results(
                model=model,
                val_metrics=val_metrics,
                test_metrics=test_metrics,
                X_val=X_val,
                y_val=y_val
            )
            
            # Store results
            self.results['xgboost'] = val_metrics
            
            print(f"✓ XGBoost - Val AUC: {val_metrics['roc_auc']:.4f}")
    
    def _train_neural_network(
        self, X_train, X_val, X_test, y_train, y_val, y_test
    ):
        """Train neural network."""
        print(f"\n{'-'*60}")
        print("Training: Neural Network")
        print(f"{'-'*60}")
        
        with mlflow.start_run(run_name="neural_network", nested=True):
            # Log parameters and tags
            mlflow.log_params({
                **self.config['models']['neural_network']['architecture'],
                **self.config['models']['neural_network']['training']
            })
            mlflow.set_tags({'model_type': 'neural_network', 'framework': 'pytorch'})
            
            # Train
            trainer = NeuralNetworkTrainer(self.config)
            model, history = trainer.train(X_train, y_train, X_val, y_val)
            
            # Log training history
            self.logger.log_nn_training_history(history)
            
            # Evaluate
            y_val_pred = trainer.predict(X_val)
            y_test_pred = trainer.predict(X_test)
            val_metrics, test_metrics = self.evaluator.evaluate_predictions(
                y_val, y_val_pred, y_test, y_test_pred
            )
            
            # Log everything to MLflow
            self.logger.log_pytorch_results(
                model=model,
                val_metrics=val_metrics,
                test_metrics=test_metrics,
                y_val=y_val,
                y_val_pred=y_val_pred
            )
            
            # Store results
            self.results['neural_network'] = val_metrics
            
            print(f"✓ Neural Network - Val AUC: {val_metrics['roc_auc']:.4f}")