"""
Bronze to Silver BATCH transformation.
Processes lab-results and medications in hourly batches.
"""

import os
import sys
from datetime import datetime, timedelta
from pyspark.sql import DataFrame
from pyspark.sql.functions import col, lit, current_timestamp, to_timestamp

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.spark_session import create_spark_session
from utils.s3_helper import build_s3_path, validate_s3_path
from transformations.deduplication import deduplicate_records, remove_exact_duplicates
from transformations.validation import validate_lab_results, validate_medications
from transformations.standardization import standardize_lab_results, standardize_medications


# ============================================================================
# BATCH PROCESSOR
# ============================================================================

class BatchProcessor:
    """
    Batch processor for non-critical clinical data (labs, medications).
    Runs on schedule (hourly) to process accumulated data.
    """
    
    def __init__(self, spark, s3_bucket: str = "clinical-mlops"):
        """
        Initialize batch processor.
        
        Args:
            spark: SparkSession
            s3_bucket: S3/MinIO bucket name
        """
        self.spark = spark
        self.s3_bucket = s3_bucket
        self.bronze_prefix = f"s3a://{s3_bucket}/raw"
        self.silver_prefix = f"s3a://{s3_bucket}/processed"
        
        # Statistics tracking
        self.stats = {
            "records_read": 0,
            "records_written": 0,
            "duplicates_removed": 0,
            "invalid_records": 0
        }
        
        print(f"✓ Initialized BatchProcessor")
        print(f"  Bronze: {self.bronze_prefix}")
        print(f"  Silver: {self.silver_prefix}")
    
    def process_lab_results(self, date: str, hour: str = None):
        """
        Process lab results for given date/hour.
        
        Pipeline:
        1. Read from Bronze (raw JSON)
        2. Remove duplicates
        3. Validate
        4. Standardize
        5. Write to Silver (Parquet)
        
        Args:
            date: Date string (YYYY-MM-DD)
            hour: Optional hour string (HH)
        """
        print(f"\n{'='*60}")
        print(f"Processing LAB RESULTS (BATCH)")
        print(f"  Date: {date}, Hour: {hour or 'all'}")
        print(f"{'='*60}")
        
        # Build input path
        input_path = f"{self.bronze_prefix}/lab_results/date={date}/"
        if hour:
            input_path += f"hour={hour}/"
        
        print(f"  Reading from: {input_path}")
        
        # Check if path exists
        if not validate_s3_path(self.spark, input_path):
            print(f"  ⚠️  No data found, skipping")
            return
        
        try:
            # Read JSON from bronze
            df = self.spark.read.json(input_path)
            initial_count = df.count()
            self.stats["records_read"] += initial_count
            print(f"  ✓ Read {initial_count:,} records")
            
            if initial_count == 0:
                print(f"  ⚠️  Empty dataset, skipping")
                return
            
            # Convert timestamp string to proper timestamp
            df = df.withColumn("timestamp", to_timestamp(col("timestamp")))
            
            # Remove exact duplicates
            df = remove_exact_duplicates(df)
            
            # Remove business-key duplicates (keep latest by timestamp)
            df = deduplicate_records(
                df,
                partition_cols=["patient_id", "test_name"],
                order_by="timestamp",
                keep="last"
            )
            after_dedup = df.count()
            duplicates = initial_count - after_dedup
            self.stats["duplicates_removed"] += duplicates
            print(f"  ✓ Removed {duplicates:,} duplicates ({after_dedup:,} remaining)")
            
            # Validate
            df = validate_lab_results(df)
            invalid_count = df.filter(~col("is_valid")).count()
            self.stats["invalid_records"] += invalid_count
            
            if invalid_count > 0:
                print(f"  ⚠️  Found {invalid_count:,} invalid records")
                print("\n  Sample invalid records:")
                df.filter(~col("is_valid")) \
                  .select("patient_id", "timestamp", "test_name", "value", "validation_failure") \
                  .show(3, truncate=False)
            
            # Keep only valid records
            df = df.filter(col("is_valid")).drop("is_valid", "validation_failure")
            
            # Standardize and enrich
            df = standardize_lab_results(df)
            
            # Add processing metadata
            df = df \
                .withColumn("processed_at", current_timestamp()) \
                .withColumn("processing_mode", lit("batch"))
            
            # Write to silver (Parquet, partitioned by date)
            output_path = f"{self.silver_prefix}/lab_results/date={date}/"
            df.coalesce(1).write.mode("overwrite").parquet(output_path)
            
            final_count = df.count()
            self.stats["records_written"] += final_count
            print(f"  ✓ Wrote {final_count:,} records to: {output_path}")
            
            # Calculate data quality score
            quality_score = (final_count / initial_count) * 100 if initial_count > 0 else 0
            print(f"  📊 Data quality: {quality_score:.1f}%")
            
        except Exception as e:
            print(f"  ✗ Error processing lab results: {e}")
            raise
    
    def process_medications(self, date: str, hour: str = None):
        """
        Process medications for given date/hour.
        
        Pipeline:
        1. Read from Bronze (raw JSON)
        2. Remove duplicates
        3. Validate
        4. Standardize
        5. Write to Silver (Parquet)
        
        Args:
            date: Date string (YYYY-MM-DD)
            hour: Optional hour string (HH)
        """
        print(f"\n{'='*60}")
        print(f"Processing MEDICATIONS (BATCH)")
        print(f"  Date: {date}, Hour: {hour or 'all'}")
        print(f"{'='*60}")
        
        # Build input path
        input_path = f"{self.bronze_prefix}/medications/date={date}/"
        if hour:
            input_path += f"hour={hour}/"
        
        print(f"  Reading from: {input_path}")
        
        # Check if path exists
        if not validate_s3_path(self.spark, input_path):
            print(f"  ⚠️  No data found, skipping")
            return
        
        try:
            # Read JSON from bronze
            df = self.spark.read.json(input_path)
            initial_count = df.count()
            self.stats["records_read"] += initial_count
            print(f"  ✓ Read {initial_count:,} records")
            
            if initial_count == 0:
                print(f"  ⚠️  Empty dataset, skipping")
                return
            
            # Convert timestamp
            df = df.withColumn("timestamp", to_timestamp(col("timestamp")))
            
            # Remove duplicates
            df = remove_exact_duplicates(df)
            df = deduplicate_records(
                df,
                partition_cols=["patient_id", "drug_name", "timestamp"],
                order_by="timestamp",
                keep="last"
            )
            after_dedup = df.count()
            duplicates = initial_count - after_dedup
            self.stats["duplicates_removed"] += duplicates
            print(f"  ✓ Removed {duplicates:,} duplicates ({after_dedup:,} remaining)")
            
            # Validate
            df = validate_medications(df)
            invalid_count = df.filter(~col("is_valid")).count()
            self.stats["invalid_records"] += invalid_count
            
            if invalid_count > 0:
                print(f"  ⚠️  Found {invalid_count:,} invalid records")
            
            # Keep only valid
            df = df.filter(col("is_valid")).drop("is_valid", "validation_failure")
            
            # Standardize
            df = standardize_medications(df)
            
            # Add metadata
            df = df \
                .withColumn("processed_at", current_timestamp()) \
                .withColumn("processing_mode", lit("batch"))
            
            # Write to silver
            output_path = f"{self.silver_prefix}/medications/date={date}/"
            df.coalesce(1).write.mode("overwrite").parquet(output_path)
            
            final_count = df.count()
            self.stats["records_written"] += final_count
            print(f"  ✓ Wrote {final_count:,} records to: {output_path}")
            
            # Calculate data quality score
            quality_score = (final_count / initial_count) * 100 if initial_count > 0 else 0
            print(f"  📊 Data quality: {quality_score:.1f}%")
            
        except Exception as e:
            print(f"  ✗ Error processing medications: {e}")
            raise
    
    def process_all(self, date: str, hour: str = None):
        """
        Process all batch data types for given date/hour.
        
        Args:
            date: Date string (YYYY-MM-DD)
            hour: Optional hour string (HH)
        """
        print(f"\n{'#'*60}")
        print(f"# Starting BATCH Processing")
        print(f"# Date: {date}, Hour: {hour or 'all'}")
        print(f"{'#'*60}")
        
        # Process lab results
        self.process_lab_results(date, hour)
        
        # Process medications
        self.process_medications(date, hour)
        
        # Print summary
        print(f"\n{'='*60}")
        print("BATCH PROCESSING SUMMARY")
        print(f"{'='*60}")
        print(f"Records Read:          {self.stats['records_read']:,}")
        print(f"Duplicates Removed:    {self.stats['duplicates_removed']:,}")
        print(f"Invalid Records:       {self.stats['invalid_records']:,}")
        print(f"Records Written:       {self.stats['records_written']:,}")
        
        if self.stats['records_read'] > 0:
            quality = (self.stats['records_written'] / self.stats['records_read']) * 100
            print(f"Overall Quality:       {quality:.1f}%")
        
        print(f"{'='*60}\n")


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    """Main entry point for batch processor."""
    # Get configuration from environment
    process_hours = int(os.getenv("PROCESS_HOURS", "1"))
    s3_bucket = os.getenv("S3_BUCKET", "clinical-mlops")
    
    # Calculate date range
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=process_hours)
    
    print("\n" + "="*60)
    print("Clinical MLOps - Batch Processor")
    print("="*60)
    print(f"Processing Window: {start_time} to {end_time}")
    print(f"Hours: {process_hours}")
    print(f"S3 Bucket: {s3_bucket}")
    print(f"Processing Mode: Batch (hourly)")
    print(f"Topics: lab-results, medications")
    print("="*60 + "\n")
    
    # Create Spark session
    spark = create_spark_session("BatchProcessor")
    
    # Create processor
    processor = BatchProcessor(spark, s3_bucket)
    
    # Process each hour in the window
    current = start_time
    processed_hours = 0
    
    while current <= end_time:
        date_str = current.strftime("%Y-%m-%d")
        hour_str = current.strftime("%H")
        
        print(f"\n{'*'*60}")
        print(f"* Processing: {date_str} Hour {hour_str}")
        print(f"{'*'*60}")
        
        try:
            processor.process_all(date_str, hour_str)
            processed_hours += 1
        except Exception as e:
            print(f"✗ Failed to process {date_str} hour {hour_str}: {e}")
            # Continue to next hour instead of failing completely
            continue
        
        # Move to next hour
        current += timedelta(hours=1)
    
    # Final summary
    print(f"\n{'='*60}")
    print("FINAL SUMMARY")
    print(f"{'='*60}")
    print(f"Total Hours Processed:  {processed_hours}")
    print(f"Total Records Read:     {processor.stats['records_read']:,}")
    print(f"Total Records Written:  {processor.stats['records_written']:,}")
    print(f"Total Duplicates:       {processor.stats['duplicates_removed']:,}")
    print(f"Total Invalid:          {processor.stats['invalid_records']:,}")
    print(f"{'='*60}\n")
    
    # Cleanup
    spark.stop()
    print("✅ Batch processing complete!")


if __name__ == "__main__":
    main()