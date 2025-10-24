"""
Model evaluation.
"""

import numpy as np
from typing import Tuple, Dict
from utils.metrics import MetricsCalculator


class ModelEvaluator:
    """Evaluate trained models."""
    
    def __init__(self):
        """Initialize evaluator."""
        self.metrics_calc = MetricsCalculator()
    
    def evaluate(
        self, model, X_val, y_val, X_test, y_test
    ) -> Tuple[Dict, Dict]:
        """
        Evaluate model on validation and test sets.
        
        Args:
            model: Trained model
            X_val: Validation features
            y_val: Validation labels
            X_test: Test features
            y_test: Test labels
            
        Returns:
            Tuple of (val_metrics, test_metrics)
        """
        # Predict probabilities
        if hasattr(model, 'predict_proba'):
            y_val_pred = model.predict_proba(X_val)[:, 1]
            y_test_pred = model.predict_proba(X_test)[:, 1]
        else:
            y_val_pred = model.predict(X_val)
            y_test_pred = model.predict(X_test)
        
        return self.evaluate_predictions(y_val, y_val_pred, y_test, y_test_pred)
    
    def evaluate_predictions(
        self, y_val, y_val_pred, y_test, y_test_pred
    ) -> Tuple[Dict, Dict]:
        """
        Evaluate predictions.
        
        Args:
            y_val: Validation labels
            y_val_pred: Validation predictions
            y_test: Test labels
            y_test_pred: Test predictions
            
        Returns:
            Tuple of (val_metrics, test_metrics)
        """
        # Calculate metrics
        val_metrics = self.metrics_calc.calculate_all_metrics(y_val, y_val_pred)
        test_metrics = self.metrics_calc.calculate_all_metrics(y_test, y_test_pred)
        
        return val_metrics, test_metrics