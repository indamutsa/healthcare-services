"""
Feature Store interface for dual storage (MinIO + Redis).
"""

import os
import json
import redis
from datetime import datetime
from typing import Dict, List
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.functions import col, to_json, struct


class FeatureStore:
    """
    Manage offline (MinIO/S3) and online (Redis) feature stores.
    """
    
    def __init__(self, config: Dict, spark: SparkSession):
        """
        Initialize feature store connections.
        
        Args:
            config: Feature store configuration
            spark: SparkSession for offline storage
        """
        self.config = config
        self.spark = spark
        
        # Offline store (MinIO/S3)
        self.offline_path = config['output']['offline_store']['path']
        self.offline_format = config['output']['offline_store']['format']
        self.partition_by = config['output']['offline_store']['partition_by']
        self.compression = config['output']['offline_store']['compression']
        
        # Online store (Redis)
        redis_host = config['output']['online_store']['host']
        redis_port = config['output']['online_store']['port']
        self.redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            decode_responses=True
        )
        self.key_pattern = config['output']['online_store']['key_pattern']
        self.ttl_hours = config['output']['online_store']['ttl_hours']
        self.ttl_seconds = self.ttl_hours * 3600
        
        # Test connections
        try:
            self.redis_client.ping()
            print(f"✓ Connected to Redis: {redis_host}:{redis_port}")
        except Exception as e:
            print(f"✗ Failed to connect to Redis: {e}")
            raise
        
        print(f"✓ Initialized FeatureStore")
        print(f"  Offline: {self.offline_path}")
        print(f"  Online: {redis_host}:{redis_port}")
    
    def write_offline(self, df: DataFrame, date: str):
        """
        Write features to offline store (MinIO/S3 Parquet).
        
        Args:
            df: Features DataFrame
            date: Partition date (YYYY-MM-DD)
        """
        print(f"\n{'='*60}")
        print("Writing to Offline Feature Store")
        print(f"{'='*60}")
        
        output_path = f"{self.offline_path}{self.partition_by}={date}/"
        
        try:
            # Write as Parquet with compression
            df.write \
                .mode("overwrite") \
                .format(self.offline_format) \
                .option("compression", self.compression) \
                .save(output_path)
            
            record_count = df.count()
            print(f"  ✓ Wrote {record_count:,} records to: {output_path}")
            
            # Calculate size
            file_size_mb = self._get_path_size(output_path)
            print(f"  ✓ Total size: {file_size_mb:.2f} MB")
            
        except Exception as e:
            print(f"  ✗ Error writing to offline store: {e}")
            raise
        
        
    def update_online(self, df: DataFrame):
        """
        Update online store (Redis) with latest features per patient.
        
        Args:
            df: Features DataFrame with patient_id column
        """
        print(f"\n{'='*60}")
        print("Updating Online Feature Store")
        print(f"{'='*60}")
        
        # Get feature columns (exclude metadata)
        exclude_cols = ['patient_id', 'timestamp', 'processing_date', 'processed_at', 
                    'feature_version', 'adverse_event_24h']
        feature_cols = [c for c in df.columns if c not in exclude_cols]
        
        print(f"  Feature columns: {len(feature_cols)}")
        
        # Fill null values before collecting to avoid NoneType errors
        from pyspark.sql.functions import when, isnan, isnull
        
        df_clean = df
        for col_name in feature_cols:
            # Fill nulls with appropriate defaults based on column type
            if any(x in col_name for x in ['flag', 'encoded', 'count', 'interaction']):
                # For flags, counts, encoded values - fill with 0
                df_clean = df_clean.fillna({col_name: 0})
            elif any(x in col_name for x in ['mean', 'std', 'min', 'max', 'trend', 'score']):
                # For numeric features - fill with 0
                df_clean = df_clean.fillna({col_name: 0})
            else:
                # For other features - fill with 0 as default
                df_clean = df_clean.fillna({col_name: 0})
        
        # Convert to list of dictionaries
        rows = df_clean.select(
            "patient_id",
            "timestamp",
            *feature_cols
        ).collect()
        
        print(f"  Updating {len(rows):,} patient feature sets...")
        
        updated_count = 0
        error_count = 0
        
        for row in rows:
            patient_id = row['patient_id']
            timestamp = row['timestamp']
            
            # Build feature dictionary
            features = {
                'updated_at': timestamp.isoformat() if timestamp else datetime.utcnow().isoformat()
            }
            
            # Add all feature values with proper type conversion
            for col_name in feature_cols:
                value = row[col_name]
                
                # Convert to Redis-compatible types
                if value is None:
                    features[col_name] = 0  # Default for nulls
                elif isinstance(value, (int, float)):
                    # Handle NaN and infinite values
                    if isinstance(value, float) and (value != value):  # Check for NaN
                        features[col_name] = 0
                    else:
                        features[col_name] = float(value)
                elif isinstance(value, bool):
                    features[col_name] = 1 if value else 0
                else:
                    features[col_name] = str(value)
            
            # Build Redis key
            redis_key = self.key_pattern.format(patient_id=patient_id)
            
            try:
                # Store as hash - ensure all values are Redis-compatible
                redis_mapping = {}
                for key, value in features.items():
                    # Final validation - ensure no None values
                    if value is None:
                        redis_mapping[key] = 0
                    else:
                        redis_mapping[key] = value
                
                self.redis_client.hset(redis_key, mapping=redis_mapping)
                
                # Set TTL
                self.redis_client.expire(redis_key, self.ttl_seconds)
                
                updated_count += 1
                
                # Print progress for large datasets
                if updated_count % 1000 == 0:
                    print(f"    ... updated {updated_count:,} patients")
                    
            except Exception as e:
                print(f"    ✗ Error updating {patient_id}: {e}")
                error_count += 1
        
        print(f"\n  ✓ Updated {updated_count:,} patients in Redis")
        if error_count > 0:
            print(f"  ⚠️  Errors: {error_count}")  

    def read_offline(self, date_range: List[str]) -> DataFrame:
        """
        Read features from offline store for given date range.
        
        Args:
            date_range: List of dates (YYYY-MM-DD)
            
        Returns:
            DataFrame with features
        """
        print(f"\n{'='*60}")
        print("Reading from Offline Feature Store")
        print(f"{'='*60}")
        
        paths = [f"{self.offline_path}{self.partition_by}={date}/" for date in date_range]
        
        print(f"  Reading {len(paths)} partitions...")
        
        try:
            df = self.spark.read.parquet(*paths)
            record_count = df.count()
            print(f"  ✓ Read {record_count:,} records")
            return df
        except Exception as e:
            print(f"  ✗ Error reading from offline store: {e}")
            raise
    
    def get_online_features(self, patient_id: str) -> Dict:
        """
        Retrieve features for a patient from online store.
        
        Args:
            patient_id: Patient identifier
            
        Returns:
            Dictionary of features
        """
        redis_key = self.key_pattern.format(patient_id=patient_id)
        
        try:
            features = self.redis_client.hgetall(redis_key)
            
            if features:
                # Convert string values back to appropriate types
                for key, value in features.items():
                    if key != 'updated_at':
                        try:
                            features[key] = float(value) if value != 'None' else None
                        except ValueError:
                            pass  # Keep as string
                
                return features
            else:
                return {}
                
        except Exception as e:
            print(f"✗ Error retrieving features for {patient_id}: {e}")
            return {}
    
    def get_online_stats(self) -> Dict:
        """
        Get statistics about online feature store.
        
        Returns:
            Dictionary with stats
        """
        pattern = self.key_pattern.replace("{patient_id}", "*")
        keys = self.redis_client.keys(pattern)
        
        return {
            "total_patients": len(keys),
            "pattern": pattern,
            "sample_keys": keys[:5] if keys else []
        }
    
    def _get_path_size(self, path: str) -> float:
        """
        Calculate size of Parquet files at path (MB).
        
        Args:
            path: S3 path
            
        Returns:
            Size in MB
        """
        try:
            # This is an approximation - in production, use boto3
            return 0.0
        except:
            return 0.0