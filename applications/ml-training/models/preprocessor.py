"""
Data preprocessing pipeline.
"""

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler, MinMaxScaler, RobustScaler
from sklearn.impute import SimpleImputer
from typing import Tuple, Optional
import joblib


class DataPreprocessor:
    """Preprocess features for ML models."""
    
    def __init__(self, config: dict):
        """
        Initialize preprocessor.
        
        Args:
            config: Preprocessing configuration
        """
        self.config = config
        self.imputer = None
        self.scaler = None
        self.feature_names = None
        
    def fit_transform(
        self,
        X_train: pd.DataFrame,
        X_val: pd.DataFrame,
        X_test: pd.DataFrame
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Fit on train and transform all sets.
        
        Args:
            X_train: Training features
            X_val: Validation features
            X_test: Test features
            
        Returns:
            Transformed (X_train, X_val, X_test)
        """
        print(f"\n{'='*60}")
        print("Preprocessing Features")
        print(f"{'='*60}")
        
        self.feature_names = X_train.columns.tolist()
        
        # 1. Handle missing values
        X_train = self._handle_missing_values(X_train, fit=True)
        X_val = self._handle_missing_values(X_val, fit=False)
        X_test = self._handle_missing_values(X_test, fit=False)
        
        # 2. Scale features
        X_train = self._scale_features(X_train, fit=True)
        X_val = self._scale_features(X_val, fit=False)
        X_test = self._scale_features(X_test, fit=False)
        
        print(f"✓ Preprocessing completed")
        print(f"  Final shape: {X_train.shape}")
        
        return X_train, X_val, X_test
    
    def _handle_missing_values(
        self, 
        X: pd.DataFrame, 
        fit: bool = False
    ) -> pd.DataFrame:
        """Handle missing values."""
        if fit:
            strategy = self.config['preprocessing']['missing_strategy']
            self.imputer = SimpleImputer(strategy=strategy)
            X_imputed = self.imputer.fit_transform(X)
            print(f"✓ Missing values handled (strategy: {strategy})")
        else:
            X_imputed = self.imputer.transform(X)
        
        return pd.DataFrame(X_imputed, columns=X.columns, index=X.index)
    
    def _scale_features(
        self, 
        X: pd.DataFrame, 
        fit: bool = False
    ) -> np.ndarray:
        """Scale features."""
        scaler_type = self.config['preprocessing']['scaler']
        
        if fit:
            # Initialize scaler
            if scaler_type == 'standard':
                self.scaler = StandardScaler()
            elif scaler_type == 'minmax':
                self.scaler = MinMaxScaler()
            elif scaler_type == 'robust':
                self.scaler = RobustScaler()
            else:
                raise ValueError(f"Unknown scaler: {scaler_type}")
            
            X_scaled = self.scaler.fit_transform(X)
            print(f"✓ Features scaled (scaler: {scaler_type})")
        else:
            X_scaled = self.scaler.transform(X)
        
        return X_scaled
    
    def save(self, path: str):
        """Save preprocessor to disk."""
        joblib.dump({
            'imputer': self.imputer,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'config': self.config
        }, path)
        print(f"✓ Preprocessor saved to: {path}")
    
    def load(self, path: str):
        """Load preprocessor from disk."""
        obj = joblib.load(path)
        self.imputer = obj['imputer']
        self.scaler = obj['scaler']
        self.feature_names = obj['feature_names']
        self.config = obj['config']
        print(f"✓ Preprocessor loaded from: {path}")