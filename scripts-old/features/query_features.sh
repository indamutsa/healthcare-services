#!/usr/bin/env python3
"""
Query and inspect features from both stores.
"""

import sys
import redis
import json
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, stddev, min as spark_min, max as spark_max


def query_offline_store(date: str):
    """Query offline feature store."""
    print("\n" + "="*60)
    print("OFFLINE FEATURE STORE (MinIO)")
    print("="*60)
    
    spark = SparkSession.builder \
        .appName("QueryOfflineStore") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .getOrCreate()
    
    path = f"s3a://clinical-mlops/features/offline/date={date}/"
    
    try:
        df = spark.read.parquet(path)
        
        print(f"\nPath: {path}")
        print(f"Total records: {df.count():,}")
        print(f"Total features: {len(df.columns)}")
        
        # Schema
        print("\nSchema (first 20 columns):")
        for field in df.schema.fields[:20]:
            print(f"  {field.name}: {field.dataType}")
        
        # Sample data
        print("\nSample data:")
        df.select(df.columns[:10]).show(5, truncate=False)
        
        # Feature statistics
        print("\nFeature Statistics (sample features):")
        feature_cols = [c for c in df.columns if 'mean_' in c or 'std_' in c][:5]
        df.select(feature_cols).describe().show()
        
        # Label distribution
        if 'adverse_event_24h' in df.columns:
            print("\nLabel Distribution:")
            df.groupBy("adverse_event_24h").count().show()
        
    except Exception as e:
        print(f"Error: {e}")
    
    finally:
        spark.stop()


def query_online_store(patient_id: str = None):
    """Query online feature store."""
    print("\n" + "="*60)
    print("ONLINE FEATURE STORE (Redis)")
    print("="*60)
    
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    # Test connection
    try:
        r.ping()
        print("✓ Connected to Redis")
    except:
        print("✗ Cannot connect to Redis")
        return
    
    # Get all patient keys
    keys = r.keys("patient:*:features")
    print(f"\nTotal patients in store: {len(keys)}")
    
    if not keys:
        print("No patient features found")
        return
    
    # Query specific patient or first one
    if patient_id:
        key = f"patient:{patient_id}:features"
    else:
        key = keys[0]
        patient_id = key.split(':')[1]
    
    print(f"\nQuerying patient: {patient_id}")
    print(f"Key: {key}")
    
    # Get all features
    features = r.hgetall(key)
    
    if not features:
        print("No features found for this patient")
        return
    
    print(f"\nTotal features: {len(features)}")
    
    # TTL
    ttl = r.ttl(key)
    print(f"TTL: {ttl // 3600} hours, {(ttl % 3600) // 60} minutes")
    
    # Sample features
    print("\nSample features:")
    for i, (fname, value) in enumerate(list(features.items())[:15]):
        print(f"  {fname}: {value}")
    
    print("\n... (truncated)")
    
    # Save full features to file
    output_file = f"./data/patient_{patient_id}_features.json"
    with open(output_file, 'w') as f:
        json.dump(features, f, indent=2)
    print(f"\n✓ Full features saved to: {output_file}")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python query_features.py offline <date>")
        print("  python query_features.py online [patient_id]")
        print("\nExamples:")
        print("  python query_features.py offline 2025-10-23")
        print("  python query_features.py online PT00042")
        sys.exit(1)
    
    store_type = sys.argv[1]
    
    if store_type == "offline":
        date = sys.argv[2] if len(sys.argv) > 2 else "2025-10-23"
        query_offline_store(date)
    
    elif store_type == "online":
        patient_id = sys.argv[2] if len(sys.argv) > 2 else None
        query_online_store(patient_id)
    
    else:
        print(f"Unknown store type: {store_type}")
        sys.exit(1)


if __name__ == "__main__":
    main()