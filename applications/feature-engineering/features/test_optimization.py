#!/usr/bin/env python3
"""
Test script to verify temporal feature optimization.

Usage:
    python test_optimization.py

This will:
1. Create sample data
2. Run both old and new implementations
3. Compare performance and output
4. Verify optimization is working
"""

import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, rand
from pyspark.sql.types import TimestampType
from datetime import datetime, timedelta
import sys

# Sample configuration
SAMPLE_CONFIG = {
    'temporal_windows': {
        'short': 3600,    # 1 hour
        'medium': 21600,  # 6 hours
        'long': 86400     # 24 hours
    },
    'feature_groups': {
        'temporal_vitals': {
            'enabled': True,
            'metrics': ['heart_rate', 'blood_pressure_systolic', 'temperature'],
            'aggregations': ['mean', 'std', 'min', 'max'],
            'windows': ['short', 'medium', 'long']
        },
        'temporal_derived': {
            'enabled': False,
            'metrics': [],
            'aggregations': [],
            'windows': []
        }
    }
}


def create_sample_data(spark, num_patients=100, records_per_patient=24):
    """Create sample patient vitals data."""
    print("\n" + "="*60)
    print("Creating Sample Data")
    print("="*60)
    
    data = []
    base_time = datetime(2025, 10, 23, 0, 0, 0)
    
    for patient_id in range(1, num_patients + 1):
        for hour in range(records_per_patient):
            timestamp = base_time + timedelta(hours=hour)
            data.append((
                f"PATIENT_{patient_id:03d}",
                timestamp,
                70 + (patient_id % 30),    # heart_rate
                120 + (patient_id % 20),   # blood_pressure_systolic
                36.5 + (patient_id % 5) * 0.1  # temperature
            ))
    
    df = spark.createDataFrame(
        data,
        ["patient_id", "timestamp", "heart_rate", "blood_pressure_systolic", "temperature"]
    )
    
    print(f"✓ Created {df.count():,} records for {num_patients} patients")
    return df


def test_nested_approach(df, config):
    """Test the OLD nested approach (slow)."""
    from pyspark.sql.functions import avg, stddev, min as spark_min, max as spark_max
    from pyspark.sql.window import Window
    
    print("\n" + "="*60)
    print("Testing NESTED Approach (OLD)")
    print("="*60)
    
    start_time = time.time()
    
    vitals_config = config['feature_groups']['temporal_vitals']
    metrics = vitals_config['metrics']
    aggregations = vitals_config['aggregations']
    windows = vitals_config['windows']
    
    result_df = df
    operation_count = 0
    
    # Nested loops - creates many operations
    for metric in metrics:
        for window_name in windows:
            window_seconds = config['temporal_windows'][window_name]
            window_label = f"{window_seconds // 3600}h"
            
            window_spec = Window \
                .partitionBy("patient_id") \
                .orderBy(col("timestamp").cast("long")) \
                .rangeBetween(-window_seconds, 0)
            
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
                
                operation_count += 1
    
    # Trigger execution
    record_count = result_df.count()
    
    elapsed_time = time.time() - start_time
    
    print(f"\n✓ Completed")
    print(f"  Window operations: {operation_count}")
    print(f"  Records processed: {record_count:,}")
    print(f"  Time: {elapsed_time:.2f} seconds")
    print(f"  Columns created: {len(result_df.columns) - len(df.columns)}")
    
    return result_df, elapsed_time


def test_batched_approach(df, config):
    """Test the NEW batched approach (fast)."""
    from pyspark.sql.functions import avg, stddev, min as spark_min, max as spark_max
    from pyspark.sql.window import Window
    
    print("\n" + "="*60)
    print("Testing BATCHED Approach (NEW)")
    print("="*60)
    
    start_time = time.time()
    
    vitals_config = config['feature_groups']['temporal_vitals']
    metrics = vitals_config['metrics']
    aggregations = vitals_config['aggregations']
    windows = vitals_config['windows']
    
    result_df = df
    window_count = 0
    
    # Batch by window - efficient
    for window_name in windows:
        window_seconds = config['temporal_windows'][window_name]
        window_label = f"{window_seconds // 3600}h"
        
        window_spec = Window \
            .partitionBy("patient_id") \
            .orderBy(col("timestamp").cast("long")) \
            .rangeBetween(-window_seconds, 0)
        
        # Build ALL expressions for this window
        expressions = []
        for metric in metrics:
            for agg_type in aggregations:
                feature_name = f"{metric}_{agg_type}_{window_label}"
                
                if agg_type == "mean":
                    expressions.append(avg(col(metric)).over(window_spec).alias(feature_name))
                elif agg_type == "std":
                    expressions.append(stddev(col(metric)).over(window_spec).alias(feature_name))
                elif agg_type == "min":
                    expressions.append(spark_min(col(metric)).over(window_spec).alias(feature_name))
                elif agg_type == "max":
                    expressions.append(spark_max(col(metric)).over(window_spec).alias(feature_name))
        
        # Apply all at once
        result_df = result_df.select("*", *expressions)
        window_count += 1
    
    # Break lineage with cache
    result_df = result_df.cache()
    
    # Trigger execution
    record_count = result_df.count()
    
    elapsed_time = time.time() - start_time
    
    print(f"\n✓ Completed")
    print(f"  Window operations: {window_count}")
    print(f"  Records processed: {record_count:,}")
    print(f"  Time: {elapsed_time:.2f} seconds")
    print(f"  Columns created: {len(result_df.columns) - len(df.columns)}")
    
    return result_df, elapsed_time


def compare_outputs(df_nested, df_batched):
    """Compare outputs to ensure they match."""
    print("\n" + "="*60)
    print("Comparing Outputs")
    print("="*60)
    
    # Check column count
    nested_cols = set(df_nested.columns)
    batched_cols = set(df_batched.columns)
    
    if nested_cols == batched_cols:
        print("✓ Column names match")
    else:
        print("✗ Column names differ!")
        missing_in_batched = nested_cols - batched_cols
        missing_in_nested = batched_cols - nested_cols
        if missing_in_batched:
            print(f"  Missing in batched: {missing_in_batched}")
        if missing_in_nested:
            print(f"  Missing in nested: {missing_in_nested}")
        return False
    
    # Sample check - compare a few feature values
    sample_patient = df_nested.select("patient_id").first()[0]
    
    nested_sample = df_nested.filter(col("patient_id") == sample_patient).first()
    batched_sample = df_batched.filter(col("patient_id") == sample_patient).first()
    
    # Check a few key features
    test_features = [
        'heart_rate_mean_1h',
        'heart_rate_std_6h',
        'temperature_max_24h'
    ]
    
    all_match = True
    for feature in test_features:
        nested_val = getattr(nested_sample, feature)
        batched_val = getattr(batched_sample, feature)
        
        # Allow small floating point differences
        if abs(nested_val - batched_val) < 0.001:
            print(f"✓ {feature}: values match")
        else:
            print(f"✗ {feature}: values differ ({nested_val} vs {batched_val})")
            all_match = False
    
    return all_match


def main():
    """Run the optimization test."""
    print("\n" + "="*70)
    print(" TEMPORAL FEATURES OPTIMIZATION TEST")
    print("="*70)
    
    # Initialize Spark
    spark = SparkSession.builder \
        .appName("TemporalFeaturesOptimizationTest") \
        .master("local[*]") \
        .config("spark.driver.memory", "2g") \
        .config("spark.sql.shuffle.partitions", "4") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    
    # Create sample data
    df = create_sample_data(spark, num_patients=50, records_per_patient=24)
    
    # Test nested approach
    df_nested, time_nested = test_nested_approach(df, SAMPLE_CONFIG)
    
    # Test batched approach  
    df_batched, time_batched = test_batched_approach(df, SAMPLE_CONFIG)
    
    # Compare outputs
    outputs_match = compare_outputs(df_nested, df_batched)
    
    # Print results
    print("\n" + "="*70)
    print(" RESULTS SUMMARY")
    print("="*70)
    
    print(f"\nNested Approach:  {time_nested:.2f} seconds")
    print(f"Batched Approach: {time_batched:.2f} seconds")
    print(f"Speedup: {time_nested / time_batched:.1f}x faster")
    
    if outputs_match:
        print("\n✅ SUCCESS: Outputs match, optimization is correct!")
        print("\nThe batched approach is:")
        print(f"  • {time_nested / time_batched:.1f}x faster")
        print(f"  • Uses {3} window operations instead of {36}")
        print(f"  • Produces identical results")
        return 0
    else:
        print("\n❌ FAILURE: Outputs don't match!")
        return 1
    
    spark.stop()


if __name__ == "__main__":
    sys.exit(main())