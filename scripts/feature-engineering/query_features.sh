#!/usr/bin/env python3
"""Query and inspect features from offline (MinIO) and online (Redis) stores."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime

import redis
from pyspark.sql import SparkSession


ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(ROOT_DIR, "data")


def query_offline_store(process_date: str) -> None:
    """Query the offline feature store (MinIO Parquet)."""
    print("\n" + "=" * 60)
    print("OFFLINE FEATURE STORE (MinIO)")
    print("=" * 60)

    spark = (
        SparkSession.builder.appName("QueryOfflineStore")
        .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000")
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .getOrCreate()
    )

    path = f"s3a://clinical-mlops/features/offline/date={process_date}/"
    print(f"Path: {path}\n")

    try:
        df = spark.read.parquet(path)
    except Exception as exc:  # pylint: disable=broad-except
        print(f"Error reading offline store: {exc}")
        spark.stop()
        return

    print(f"Total records: {df.count():,}")
    print(f"Total features: {len(df.columns)}")

    print("\nSchema (first 20 columns):")
    for field in df.schema.fields[:20]:
        print(f"  {field.name}: {field.dataType}")

    print("\nSample data:")
    df.select(df.columns[:10]).show(5, truncate=False)

    print("\nFeature Statistics (sample):")
    feature_cols = [c for c in df.columns if "mean_" in c or "std_" in c][:5]
    if feature_cols:
        df.select(feature_cols).describe().show()

    if "adverse_event_24h" in df.columns:
        print("\nLabel Distribution:")
        df.groupBy("adverse_event_24h").count().show()

    spark.stop()


def query_online_store(patient_id: str | None) -> None:
    """Query the online feature store (Redis)."""
    print("\n" + "=" * 60)
    print("ONLINE FEATURE STORE (Redis)")
    print("=" * 60)

    client = redis.Redis(host="localhost", port=6379, decode_responses=True)

    try:
        client.ping()
        print("✓ Connected to Redis")
    except redis.RedisError as exc:
        print(f"✗ Cannot connect to Redis: {exc}")
        return

    keys = client.keys("patient:*:features")
    print(f"\nTotal patients in store: {len(keys)}")

    if not keys:
        print("No patient features found")
        return

    key = f"patient:{patient_id}:features" if patient_id else keys[0]
    resolved_patient = key.split(":")[1]

    print(f"\nQuerying patient: {resolved_patient}")
    print(f"Key: {key}")

    features = client.hgetall(key)
    if not features:
        print("No features found for this patient")
        return

    print(f"\nTotal features: {len(features)}")
    ttl = client.ttl(key)
    if ttl and ttl > 0:
        hours, remainder = divmod(ttl, 3600)
        minutes = remainder // 60
        print(f"TTL: {hours} hours, {minutes} minutes")

    print("\nSample features:")
    for idx, (fname, value) in enumerate(features.items()):
        if idx >= 15:
            break
        print(f"  {fname}: {value}")

    print("\n... (truncated)")

    os.makedirs(DATA_DIR, exist_ok=True)
    output_file = os.path.join(DATA_DIR, f"patient_{resolved_patient}_features.json")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(features, f, indent=2)
    print(f"\n✓ Full features saved to: {output_file}")


def print_usage() -> None:
    print("Usage:")
    print("  ./query_features.sh offline <YYYY-MM-DD>")
    print("  ./query_features.sh online [PATIENT_ID]")
    print("\nExamples:")
    today = datetime.utcnow().strftime("%Y-%m-%d")
    print(f"  ./query_features.sh offline {today}")
    print("  ./query_features.sh online PT00042")


def main() -> None:
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    mode = sys.argv[1].lower()

    if mode == "offline":
        date_arg = sys.argv[2] if len(sys.argv) > 2 else datetime.utcnow().strftime("%Y-%m-%d")
        query_offline_store(date_arg)
    elif mode == "online":
        patient_arg = sys.argv[2] if len(sys.argv) > 2 else None
        query_online_store(patient_arg)
    else:
        print(f"Unknown store type: {mode}\n")
        print_usage()
        sys.exit(1)


if __name__ == "__main__":
    main()
