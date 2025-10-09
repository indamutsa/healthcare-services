"""
Spark session creation with S3/MinIO configuration.
Handles all the necessary settings for connecting to MinIO and Kafka.
"""

import os
from pyspark.sql import SparkSession


def create_spark_session(app_name: str = "ClinicalMLOps") -> SparkSession:
    """
    Create SparkSession with S3/MinIO and Kafka configuration.
    
    Args:
        app_name: Application name for Spark UI
        
    Returns:
        Configured SparkSession
    """
    # Get configuration from environment
    s3_endpoint = os.getenv("S3_ENDPOINT", "http://minio:9000")
    s3_access_key = os.getenv("S3_ACCESS_KEY", "minioadmin")
    s3_secret_key = os.getenv("S3_SECRET_KEY", "minioadmin")
    
    builder = SparkSession.builder \
        .appName(app_name) \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.sql.streaming.checkpointLocation", f"s3a://clinical-mlops/checkpoints/{app_name}") \
        .config("spark.hadoop.fs.s3a.endpoint", s3_endpoint) \
        .config("spark.hadoop.fs.s3a.access.key", s3_access_key) \
        .config("spark.hadoop.fs.s3a.secret.key", s3_secret_key) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
        .config("spark.sql.parquet.compression.codec", "snappy") \
        .config("spark.sql.shuffle.partitions", "10")
    
    spark = builder.getOrCreate()
    
    # Set log level
    spark.sparkContext.setLogLevel("WARN")
    
    print(f"✓ Created SparkSession: {app_name}")
    print(f"  S3 Endpoint: {s3_endpoint}")
    print(f"  Spark UI: http://<driver-ip>:4040")
    
    return spark