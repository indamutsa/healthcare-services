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
    ) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
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
        
        # Drop non-numeric columns that can't be processed
        non_numeric_cols = X_train.select_dtypes(exclude=['number']).columns
        if len(non_numeric_cols) > 0:
            print(f"⚠ Dropping non-numeric columns: {list(non_numeric_cols)}")
            X_train = X_train.drop(columns=non_numeric_cols)
            X_val = X_val.drop(columns=non_numeric_cols)
            X_test = X_test.drop(columns=non_numeric_cols)
        
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
        # Select only numeric columns for imputation
        numeric_cols = X.select_dtypes(include=['number']).columns
        non_numeric_cols = X.select_dtypes(exclude=['number']).columns
        
        if fit:
            strategy = self.config['preprocessing']['missing_strategy']
            self.imputer = SimpleImputer(strategy=strategy)
            # Only impute numeric columns that have at least some valid values
            valid_numeric_cols = []
            for col in numeric_cols:
                if X[col].notna().sum() > 0:  # At least one non-null value
                    valid_numeric_cols.append(col)
            
            if len(valid_numeric_cols) > 0:
                X_numeric = pd.DataFrame(
                    self.imputer.fit_transform(X[valid_numeric_cols]), 
                    columns=valid_numeric_cols,
                    index=X.index
                )
            else:
                X_numeric = X[numeric_cols]
            print(f"✓ Missing values handled (strategy: {strategy})")
        else:
            # Only impute numeric columns that have at least some valid values
            valid_numeric_cols = []
            for col in numeric_cols:
                if X[col].notna().sum() > 0:  # At least one non-null value
                    valid_numeric_cols.append(col)
            
            if len(valid_numeric_cols) > 0:
                X_numeric = pd.DataFrame(
                    self.imputer.transform(X[valid_numeric_cols]), 
                    columns=valid_numeric_cols,
                    index=X.index
                )
            else:
                X_numeric = X[numeric_cols]
        
        # Keep non-numeric columns as-is (they'll be handled by encoding)
        X_non_numeric = X[non_numeric_cols]
        
        return pd.concat([X_numeric, X_non_numeric], axis=1)
    
    def _scale_features(
        self, 
        X: pd.DataFrame, 
        fit: bool = False
    ) -> pd.DataFrame:
        """Scale features."""
        scaler_type = self.config['preprocessing']['scaler']
        
        # Select only numeric columns for scaling
        numeric_cols = X.select_dtypes(include=['number']).columns
        non_numeric_cols = X.select_dtypes(exclude=['number']).columns
        
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
            
            # Only scale numeric columns
            X_numeric = pd.DataFrame(
                self.scaler.fit_transform(X[numeric_cols]), 
                columns=numeric_cols,
                index=X.index
            )
            print(f"✓ Features scaled (scaler: {scaler_type})")
        else:
            # Only scale numeric columns
            X_numeric = pd.DataFrame(
                self.scaler.transform(X[numeric_cols]), 
                columns=numeric_cols,
                index=X.index
            )
        
        # Keep non-numeric columns as-is
        X_non_numeric = X[non_numeric_cols]
        
        return pd.concat([X_numeric, X_non_numeric], axis=1)
    
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