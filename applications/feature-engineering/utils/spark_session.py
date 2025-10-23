"""
Spark session configuration for feature engineering.
"""

import os
from pyspark.sql import SparkSession


def create_feature_engineering_spark(app_name: str = "FeatureEngineering") -> SparkSession:
    """
    Create Spark session optimized for feature engineering.
    
    Args:
        app_name: Application name for Spark
        
    Returns:
        Configured SparkSession
    """
    # Get S3 configuration from environment
    s3_endpoint = os.getenv("S3_ENDPOINT", "http://minio:9000")
    s3_access_key = os.getenv("S3_ACCESS_KEY", "minioadmin")
    s3_secret_key = os.getenv("S3_SECRET_KEY", "minioadmin")
    
    spark = SparkSession.builder \
        .appName(app_name) \
        .config("spark.jars.packages", "org.apache.hadoop:hadoop-aws:3.3.4") \
        .config("spark.hadoop.fs.s3a.endpoint", s3_endpoint) \
        .config("spark.hadoop.fs.s3a.access.key", s3_access_key) \
        .config("spark.hadoop.fs.s3a.secret.key", s3_secret_key) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
        .config("spark.sql.session.timeZone", "UTC") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    
    print(f"✓ Spark session created: {app_name}")
    print(f"  Spark version: {spark.version}")
    print(f"  S3 endpoint: {s3_endpoint}")
    
    return spark