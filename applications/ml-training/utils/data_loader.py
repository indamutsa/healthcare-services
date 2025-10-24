"""
Load and prepare data from feature store.
"""

import pandas as pd
import numpy as np
from typing import Tuple, List
from pyspark.sql import SparkSession
from datetime import datetime


class FeatureStoreLoader:
    """Load features from offline feature store."""
    
    def __init__(self, config: dict):
        """
        Initialize loader.
        
        Args:
            config: Configuration dictionary
        """
        self.config = config
        self.spark = self._init_spark()
        
    def _init_spark(self) -> SparkSession:
        """Initialize Spark session with S3 configuration."""
        print("Initializing Spark session...")
        
        spark = SparkSession.builder \
            .appName("FeatureLoader") \
            .config("spark.hadoop.fs.s3a.endpoint", self.config['s3']['endpoint']) \
            .config("spark.hadoop.fs.s3a.access.key", self.config['s3']['access_key']) \
            .config("spark.hadoop.fs.s3a.secret.key", self.config['s3']['secret_key']) \
            .config("spark.hadoop.fs.s3a.path.style.access", "true") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .getOrCreate()
        
        print("✓ Spark session initialized")
        return spark
    
    def load_data(self) -> pd.DataFrame:
        """
        Load features from offline store.
        
        Returns:
            DataFrame with features and target
        """
        print(f"\n{'='*60}")
        print("Loading Data from Feature Store")
        print(f"{'='*60}")
        
        start_date = self.config['data']['start_date']
        end_date = self.config['data']['end_date']
        path = self.config['data']['offline_store_path']
        
        print(f"Path: {path}")
        print(f"Date range: {start_date} to {end_date}")
        
        try:
            # Read parquet files
            df_spark = self.spark.read.parquet(path)
            
            # Filter by date range if date column exists
            if 'date' in df_spark.columns:
                df_spark = df_spark.filter(
                    (df_spark.date >= start_date) & 
                    (df_spark.date <= end_date)
                )
            
            # Convert to pandas
            df = df_spark.toPandas()
            
            print(f"✓ Loaded {len(df):,} records")
            print(f"✓ Columns: {len(df.columns)}")
            print(f"✓ Memory: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
            
            # Basic data quality checks
            self._validate_data(df)
            
            return df
            
        except Exception as e:
            print(f"✗ Error loading data: {e}")
            raise
    
    def _validate_data(self, df: pd.DataFrame):
        """Validate loaded data."""
        target_col = self.config['data']['target_column']
        
        # Check target column exists
        if target_col not in df.columns:
            raise ValueError(f"Target column '{target_col}' not found in data")
        
        # Check for missing values
        missing_pct = df.isnull().sum() / len(df) * 100
        if missing_pct.max() > 50:
            print(f"⚠ Warning: Some columns have >50% missing values")
        
        # Check target distribution
        target_dist = df[target_col].value_counts(normalize=True)
        print(f"\nTarget distribution:")
        for val, pct in target_dist.items():
            print(f"  {val}: {pct:.2%}")
        
        if target_dist.min() < 0.01:
            print(f"⚠ Warning: Severe class imbalance detected")
    
    def prepare_features(
        self, 
        df: pd.DataFrame
    ) -> Tuple[pd.DataFrame, pd.Series, pd.Series, List[str]]:
        """
        Prepare features and target.
        
        Args:
            df: Raw DataFrame
            
        Returns:
            Tuple of (X, y, timestamps, feature_names)
        """
        print(f"\n{'='*60}")
        print("Preparing Features")
        print(f"{'='*60}")
        
        # Get target column
        target_col = self.config['data']['target_column']
        y = df[target_col]
        
        # Get timestamp for temporal split
        if 'timestamp' in df.columns:
            timestamps = pd.to_datetime(df['timestamp'])
        else:
            # Use index as proxy if no timestamp
            timestamps = pd.Series(range(len(df)), index=df.index)
        
        # Get feature columns
        exclude_cols = set(self.config['data']['exclude_columns'])
        feature_cols = [col for col in df.columns if col not in exclude_cols]
        
        # Extract features
        X = df[feature_cols].copy()
        
        # Handle infinite values
        X.replace([np.inf, -np.inf], np.nan, inplace=True)
        
        print(f"✓ Features: {X.shape[1]} columns")
        print(f"✓ Samples: {len(X):,} rows")
        print(f"✓ Target: {y.name}")
        print(f"  Positive: {y.sum():,} ({y.mean():.2%})")
        print(f"  Negative: {(~y.astype(bool)).sum():,} ({1-y.mean():.2%})")
        
        return X, y, timestamps, feature_cols
    
    def temporal_split(
        self,
        X: pd.DataFrame,
        y: pd.Series,
        timestamps: pd.Series
    ) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame,
               pd.Series, pd.Series, pd.Series]:
        """
        Split data temporally to prevent data leakage.
        
        Args:
            X: Features
            y: Target
            timestamps: Timestamps
            
        Returns:
            X_train, X_val, X_test, y_train, y_val, y_test
        """
        print(f"\n{'='*60}")
        print("Temporal Data Split")
        print(f"{'='*60}")
        
        # Sort by timestamp
        sorted_idx = timestamps.sort_values().index
        
        # Get split ratios
        train_ratio = self.config['data']['split_ratios']['train']
        val_ratio = self.config['data']['split_ratios']['val']
        
        # Calculate split points
        n = len(sorted_idx)
        train_end = int(train_ratio * n)
        val_end = int((train_ratio + val_ratio) * n)
        
        # Split indices
        train_idx = sorted_idx[:train_end]
        val_idx = sorted_idx[train_end:val_end]
        test_idx = sorted_idx[val_end:]
        
        # Split data
        X_train, y_train = X.loc[train_idx], y.loc[train_idx]
        X_val, y_val = X.loc[val_idx], y.loc[val_idx]
        X_test, y_test = X.loc[test_idx], y.loc[test_idx]
        
        # Print split summary
        print(f"Train: {len(X_train):,} samples ({len(X_train)/n:.1%})")
        print(f"  Positive rate: {y_train.mean():.3f}")
        print(f"  Date range: {timestamps.loc[train_idx].min()} to {timestamps.loc[train_idx].max()}")
        
        print(f"\nValidation: {len(X_val):,} samples ({len(X_val)/n:.1%})")
        print(f"  Positive rate: {y_val.mean():.3f}")
        print(f"  Date range: {timestamps.loc[val_idx].min()} to {timestamps.loc[val_idx].max()}")
        
        print(f"\nTest: {len(X_test):,} samples ({len(X_test)/n:.1%})")
        print(f"  Positive rate: {y_test.mean():.3f}")
        print(f"  Date range: {timestamps.loc[test_idx].min()} to {timestamps.loc[test_idx].max()}")
        
        return X_train, X_val, X_test, y_train, y_val, y_test
    
    def close(self):
        """Close Spark session."""
        if self.spark:
            self.spark.stop()
            print("✓ Spark session closed")