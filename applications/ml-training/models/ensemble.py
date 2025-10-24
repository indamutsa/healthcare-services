"""
Ensemble model combining multiple classifiers.
"""

import numpy as np
from typing import List, Dict, Optional
from sklearn.ensemble import VotingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
import xgboost as xgb


class EnsembleModel:
    """Ensemble of multiple models."""
    
    def __init__(self, config: dict):
        """
        Initialize ensemble.
        
        Args:
            config: Ensemble configuration
        """
        self.config = config
        self.models = {}
        self.ensemble = None
        
    def add_model(self, name: str, model):
        """
        Add model to ensemble.
        
        Args:
            name: Model name
            model: Trained model
        """
        self.models[name] = model
        print(f"✓ Added {name} to ensemble")
    
    def build_ensemble(self) -> VotingClassifier:
        """
        Build voting ensemble.
        
        Returns:
            Voting classifier
        """
        if not self.models:
            raise ValueError("No models added to ensemble")
        
        print(f"\n{'='*60}")
        print("Building Ensemble")
        print(f"{'='*60}")
        
        # Prepare estimators
        estimators = [(name, model) for name, model in self.models.items()]
        
        # Get weights if specified
        weights = self.config['ensemble'].get('weights', None)
        
        # Build voting classifier
        voting_type = self.config['ensemble']['voting_type']
        self.ensemble = VotingClassifier(
            estimators=estimators,
            voting=voting_type,
            weights=weights
        )
        
        print(f"✓ Ensemble created")
        print(f"  Method: {self.config['ensemble']['method']}")
        print(f"  Voting: {voting_type}")
        print(f"  Models: {list(self.models.keys())}")
        if weights:
            print(f"  Weights: {weights}")
        
        return self.ensemble
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """
        Predict using ensemble.
        
        Args:
            X: Features
            
        Returns:
            Predicted probabilities
        """
        if self.ensemble is None:
            raise ValueError("Ensemble not built yet")
        
        if self.config['ensemble']['voting_type'] == 'soft':
            return self.ensemble.predict_proba(X)[:, 1]
        else:
            return self.ensemble.predict(X)
    
    def get_individual_predictions(self, X: np.ndarray) -> Dict[str, np.ndarray]:
        """
        Get predictions from individual models.
        
        Args:
            X: Features
            
        Returns:
            Dictionary of predictions per model
        """
        predictions = {}
        
        for name, model in self.models.items():
            if hasattr(model, 'predict_proba'):
                pred = model.predict_proba(X)[:, 1]
            else:
                pred = model.predict(X)
            predictions[name] = pred
        
        return predictions