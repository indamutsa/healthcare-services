"""
Temporal feature generation using rolling window aggregations.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import col, avg, stddev, min as spark_min, max as spark_max
from pyspark.sql.window import Window
from typing import Dict, List


class TemporalFeatureGenerator:
    """
    Generate temporal features using rolling time windows.
    Uses PySpark Window functions for efficient computation.
    """
    
    def __init__(self, config: Dict):
        """
        Initialize with feature configuration.
        
        Args:
            config: Feature configuration dictionary
        """
        self.config = config
        self.windows = {
            'short': config['temporal_windows']['short'],
            'medium': config['temporal_windows']['medium'],
            'long': config['temporal_windows']['long']
        }
        
        print(f"✓ Initialized TemporalFeatureGenerator")
        print(f"  Windows: 1h={self.windows['short']}s, 6h={self.windows['medium']}s, 24h={self.windows['long']}s")
    
    def generate_features(self, df: DataFrame) -> DataFrame:
        """
        Generate temporal features for all configured metrics.
        
        Args:
            df: Input DataFrame with timestamp and metrics
            
        Returns:
            DataFrame with added temporal features
        """
        print(f"\n{'='*60}")
        print("Generating Temporal Features")
        print(f"{'='*60}")
        
        # Get configuration for temporal vitals
        vitals_config = self.config['feature_groups']['temporal_vitals']
        metrics = vitals_config['metrics']
        aggregations = vitals_config['aggregations']
        window_names = vitals_config['windows']
        
        result_df = df
        feature_count = 0
        
        # Generate features for each metric
        for metric in metrics:
            print(f"\n  Processing metric: {metric}")
            
            # Generate features for each window size
            for window_name in window_names:
                window_seconds = self.windows[window_name]
                window_label = self._get_window_label(window_seconds)
                
                # Create time-based window
                window_spec = Window \
                    .partitionBy("patient_id") \
                    .orderBy(col("timestamp").cast("long")) \
                    .rangeBetween(-window_seconds, 0)
                
                # Generate aggregations
                for agg_type in aggregations:
                    feature_name = f"{metric}_{agg_type}_{window_label}"
                    
                    if agg_type == "mean":
                        result_df = result_df.withColumn(
                            feature_name,
                            avg(col(metric)).over(window_spec)
                        )
                    
                    elif agg_type == "std":
                        result_df = result_df.withColumn(
                            feature_name,
                            stddev(col(metric)).over(window_spec)
                        )
                    
                    elif agg_type == "min":
                        result_df = result_df.withColumn(
                            feature_name,
                            spark_min(col(metric)).over(window_spec)
                        )
                    
                    elif agg_type == "max":
                        result_df = result_df.withColumn(
                            feature_name,
                            spark_max(col(metric)).over(window_spec)
                        )
                    
                    elif agg_type == "trend":
                        # Linear regression slope approximation
                        # (later value - earlier value) / time_diff
                        result_df = result_df.withColumn(
                            feature_name,
                            (col(metric) - avg(col(metric)).over(window_spec)) / window_seconds * 3600
                        )
                    
                    feature_count += 1
        
        # Generate derived temporal features
        derived_config = self.config['feature_groups']['temporal_derived']
        if derived_config['enabled']:
            result_df = self._generate_derived_temporal(result_df, derived_config)
            feature_count += self._count_derived_features(derived_config)
        
        print(f"\n  ✓ Generated {feature_count} temporal features")
        return result_df
    
    def _generate_derived_temporal(self, df: DataFrame, config: Dict) -> DataFrame:
        """Generate temporal features for derived metrics."""
        print(f"\n  Processing derived metrics")
        
        metrics = config['metrics']
        aggregations = config['aggregations']
        window_names = config['windows']
        
        result_df = df
        
        for metric in metrics:
            for window_name in window_names:
                window_seconds = self.windows[window_name]
                window_label = self._get_window_label(window_seconds)
                
                window_spec = Window \
                    .partitionBy("patient_id") \
                    .orderBy(col("timestamp").cast("long")) \
                    .rangeBetween(-window_seconds, 0)
                
                for agg_type in aggregations:
                    if agg_type in ["mean", "std", "trend"]:
                        feature_name = f"{metric}_{agg_type}_{window_label}"
                        
                        if agg_type == "mean":
                            result_df = result_df.withColumn(
                                feature_name,
                                avg(col(metric)).over(window_spec)
                            )
                        elif agg_type == "std":
                            result_df = result_df.withColumn(
                                feature_name,
                                stddev(col(metric)).over(window_spec)
                            )
                        elif agg_type == "trend":
                            result_df = result_df.withColumn(
                                feature_name,
                                (col(metric) - avg(col(metric)).over(window_spec)) / window_seconds * 3600
                            )
        
        return result_df
    
    def _get_window_label(self, seconds: int) -> str:
        """Convert seconds to readable label."""
        hours = seconds // 3600
        return f"{hours}h"
    
    def _count_derived_features(self, config: Dict) -> int:
        """Count number of derived features."""
        metrics = config['metrics']
        aggregations = [a for a in config['aggregations'] if a in ["mean", "std", "trend"]]
        windows = config['windows']
        return len(metrics) * len(aggregations) * len(windows)
    
    def get_feature_names(self) -> List[str]:
        """Get list of all temporal feature names."""
        features = []
        
        # Vitals features
        vitals_config = self.config['feature_groups']['temporal_vitals']
        for metric in vitals_config['metrics']:
            for window_name in vitals_config['windows']:
                window_seconds = self.windows[window_name]
                window_label = self._get_window_label(window_seconds)
                for agg_type in vitals_config['aggregations']:
                    features.append(f"{metric}_{agg_type}_{window_label}")
        
        # Derived features
        derived_config = self.config['feature_groups']['temporal_derived']
        if derived_config['enabled']:
            for metric in derived_config['metrics']:
                for window_name in derived_config['windows']:
                    window_seconds = self.windows[window_name]
                    window_label = self._get_window_label(window_seconds)
                    for agg_type in derived_config['aggregations']:
                        if agg_type in ["mean", "std", "trend"]:
                            features.append(f"{metric}_{agg_type}_{window_label}")
        
        return features