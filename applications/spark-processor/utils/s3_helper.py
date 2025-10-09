"""
S3/MinIO helper functions for Spark jobs.
"""

from typing import List
from datetime import datetime


def build_s3_path(bucket: str, prefix: str, date: str, hour: str = None) -> str:
    """
    Build S3 path with partitioning.
    
    Args:
        bucket: S3 bucket name
        prefix: Prefix/folder path
        date: Date string (YYYY-MM-DD)
        hour: Optional hour string (HH)
        
    Returns:
        Full S3 path
    """
    path = f"s3a://{bucket}/{prefix}/date={date}/"
    if hour:
        path += f"hour={hour}/"
    return path


def get_date_hour_now() -> tuple:
    """
    Get current date and hour in UTC.
    
    Returns:
        Tuple of (date_str, hour_str)
    """
    now = datetime.utcnow()
    return now.strftime("%Y-%m-%d"), now.strftime("%H")


def validate_s3_path(spark, path: str) -> bool:
    """
    Check if S3 path exists and has data.
    
    Args:
        spark: SparkSession
        path: S3 path to check
        
    Returns:
        True if path exists with data
    """
    try:
        # Try to read - if it fails, path doesn't exist or is empty
        df = spark.read.json(path)
        count = df.count()
        return count > 0
    except Exception:
        return False