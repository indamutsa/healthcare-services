"""
Bronze to Silver STREAMING transformation.
Processes patient-vitals and adverse-events in real-time using Spark Structured Streaming.
"""

import os
import sys
from pyspark.sql import DataFrame
from pyspark.sql.functions import (
    col, from_json, to_timestamp, current_timestamp, 
    lit, window, count, avg, stddev, min as spark_min, max as spark_max
)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.spark_session import create_spark_session
from transformations.validation import validate_vitals, validate_adverse_events
from transformations.standardization import standardize_vitals, standardize_adverse_events


# ============================================================================
# KAFKA MESSAGE SCHEMAS
# ============================================================================

VITALS_SCHEMA = StructType([
    StructField("patient_id", StringType(), False),
    StructField("timestamp", StringType(), False),
    StructField("heart_rate", IntegerType(), True),
    StructField("blood_pressure_systolic", IntegerType(), True),
    StructField("blood_pressure_diastolic", IntegerType(), True),
    StructField("temperature", DoubleType(), True),
    StructField("spo2", IntegerType(), True),
    StructField("source", StringType(), True),
    StructField("trial_site", StringType(), True),
    StructField("trial_arm", StringType(), True),
])

ADVERSE_EVENTS_SCHEMA = StructType([
    StructField("patient_id", StringType(), False),
    StructField("event_timestamp", StringType(), False),
    StructField("event_type", StringType(), False),
    StructField("severity", StringType(), False),
    StructField("reported_by", StringType(), True),
    StructField("report_timestamp", StringType(), True),
    StructField("trial_site", StringType(), True),
    StructField("trial_arm", StringType(), True),
    StructField("description", StringType(), True),
])


# ============================================================================
# STREAMING PROCESSOR
# ============================================================================

class StreamingProcessor:
    """
    Real-time processor for critical clinical data streams.
    """
    
    def __init__(
        self,
        spark,
        kafka_bootstrap_servers: str = "kafka:29092",
        s3_bucket: str = "clinical-mlops"
    ):
        """
        Initialize streaming processor.
        
        Args:
            spark: SparkSession with streaming enabled
            kafka_bootstrap_servers: Kafka broker addresses
            s3_bucket: S3/MinIO bucket for output
        """
        self.spark = spark
        self.kafka_servers = kafka_bootstrap_servers
        self.s3_bucket = s3_bucket
        self.silver_prefix = f"s3a://{s3_bucket}/processed"
        self.checkpoint_base = f"s3a://{s3_bucket}/checkpoints"
        
        print(f"✓ Initialized StreamingProcessor")
        print(f"  Kafka: {kafka_bootstrap_servers}")
        print(f"  Output: {self.silver_prefix}")
        print(f"  Checkpoints: {self.checkpoint_base}")
    
    def read_kafka_stream(self, topic: str) -> DataFrame:
        """
        Read streaming data from Kafka topic.
        
        Args:
            topic: Kafka topic name
            
        Returns:
            Streaming DataFrame
        """
        return self.spark \
            .readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", self.kafka_servers) \
            .option("subscribe", topic) \
            .option("startingOffsets", "latest") \
            .option("failOnDataLoss", "false") \
            .option("maxOffsetsPerTrigger", "1000") \
            .load()
    
    def process_vitals_stream(self):
        """
        Process patient vitals in real-time.
        
        Pipeline:
        1. Read from Kafka (patient-vitals topic)
        2. Parse JSON messages
        3. Validate against physiological ranges
        4. Standardize and enrich (derive MAP, pulse pressure, etc.)
        5. Write to Silver layer (Parquet, partitioned by date)
        """
        print("\n" + "="*60)
        print("Starting VITALS streaming pipeline")
        print("="*60)
        
        # Read from Kafka
        raw_stream = self.read_kafka_stream("patient-vitals")
        
        # Parse JSON from Kafka value field
        parsed_stream = raw_stream.select(
            from_json(col("value").cast("string"), VITALS_SCHEMA).alias("data"),
            col("timestamp").alias("kafka_timestamp")
        ).select("data.*", "kafka_timestamp")
        
        # Convert timestamp string to proper timestamp type
        parsed_stream = parsed_stream.withColumn(
            "timestamp",
            to_timestamp(col("timestamp"))
        )
        
        # Validate records
        validated_stream = validate_vitals(parsed_stream)
        
        # Log invalid records (for monitoring)
        invalid_count_query = validated_stream.filter(~col("is_valid")) \
            .writeStream \
            .outputMode("append") \
            .format("console") \
            .option("truncate", "false") \
            .queryName("vitals_invalid_records") \
            .trigger(processingTime="30 seconds") \
            .start()
        
        # Filter only valid records
        clean_stream = validated_stream.filter(col("is_valid")) \
            .drop("is_valid", "validation_failure")
        
        # Standardize and enrich
        enriched_stream = standardize_vitals(clean_stream)
        
        # Add processing metadata
        enriched_stream = enriched_stream \
            .withColumn("processed_at", current_timestamp()) \
            .withColumn("processing_mode", lit("streaming"))
        
        # Write to Silver layer (Parquet, partitioned)
        parquet_query = enriched_stream \
            .writeStream \
            .outputMode("append") \
            .format("parquet") \
            .option("path", f"{self.silver_prefix}/patient_vitals_stream/") \
            .option("checkpointLocation", f"{self.checkpoint_base}/vitals_parquet") \
            .partitionBy("processing_date") \
            .queryName("vitals_to_silver") \
            .trigger(processingTime="10 seconds") \
            .start()
        
        print(f"✓ Vitals stream started")
        print(f"  Output: {self.silver_prefix}/patient_vitals_stream/")
        print(f"  Checkpoint: {self.checkpoint_base}/vitals_parquet")
        print(f"  Trigger: Every 10 seconds")
        
        return [parquet_query, invalid_count_query]
    
    def process_adverse_events_stream(self):
        """
        Process adverse events in real-time.
        Critical events need immediate processing for safety alerts.
        """
        print("\n" + "="*60)
        print("Starting ADVERSE EVENTS streaming pipeline")
        print("="*60)
        
        # Read from Kafka
        raw_stream = self.read_kafka_stream("adverse-events")
        
        # Parse JSON
        parsed_stream = raw_stream.select(
            from_json(col("value").cast("string"), ADVERSE_EVENTS_SCHEMA).alias("data"),
            col("timestamp").alias("kafka_timestamp")
        ).select("data.*", "kafka_timestamp")
        
        # Convert timestamps
        parsed_stream = parsed_stream \
            .withColumn("event_timestamp", to_timestamp(col("event_timestamp"))) \
            .withColumn("report_timestamp", to_timestamp(col("report_timestamp")))
        
        # Validate
        validated_stream = validate_adverse_events(parsed_stream)
        
        # Filter valid records
        clean_stream = validated_stream.filter(col("is_valid")) \
            .drop("is_valid", "validation_failure")
        
        # Standardize
        enriched_stream = standardize_adverse_events(clean_stream)
        
        # Add metadata
        enriched_stream = enriched_stream \
            .withColumn("processed_at", current_timestamp()) \
            .withColumn("processing_mode", lit("streaming"))
        
        # Write to Silver layer
        parquet_query = enriched_stream \
            .writeStream \
            .outputMode("append") \
            .format("parquet") \
            .option("path", f"{self.silver_prefix}/adverse_events_stream/") \
            .option("checkpointLocation", f"{self.checkpoint_base}/adverse_events_parquet") \
            .partitionBy("processing_date") \
            .queryName("adverse_events_to_silver") \
            .trigger(processingTime="5 seconds") \
            .start()
        
        print(f"✓ Adverse events stream started")
        print(f"  Output: {self.silver_prefix}/adverse_events_stream/")
        print(f"  Trigger: Every 5 seconds (critical data)")
        
        return [parquet_query]
    
    def start_monitoring_console(self):
        """
        Console output for monitoring streaming progress.
        Shows real-time statistics in 30-second windows.
        """
        print("\n" + "="*60)
        print("Starting monitoring console (30-second windows)")
        print("="*60)
        
        # Read vitals stream
        vitals_stream = self.read_kafka_stream("patient-vitals")
        parsed_vitals = vitals_stream.select(
            from_json(col("value").cast("string"), VITALS_SCHEMA).alias("data")
        ).select("data.*")
        
        # Convert timestamp
        parsed_vitals = parsed_vitals.withColumn(
            "timestamp",
            to_timestamp(col("timestamp"))
        )
        
        # Aggregate stats in 30-second tumbling windows
        vitals_stats = parsed_vitals \
            .withWatermark("timestamp", "1 minute") \
            .groupBy(window(col("timestamp"), "30 seconds")) \
            .agg(
                count("*").alias("total_records"),
                avg("heart_rate").alias("avg_heart_rate"),
                stddev("heart_rate").alias("stddev_heart_rate"),
                avg("blood_pressure_systolic").alias("avg_bp_systolic"),
                avg("temperature").alias("avg_temperature"),
                spark_min("spo2").alias("min_spo2"),
                spark_max("spo2").alias("max_spo2")
            ) \
            .select(
                col("window.start").alias("window_start"),
                col("window.end").alias("window_end"),
                "total_records",
                "avg_heart_rate",
                "stddev_heart_rate",
                "avg_bp_systolic",
                "avg_temperature",
                "min_spo2",
                "max_spo2"
            )
        
        # Write to console
        console_query = vitals_stats \
            .writeStream \
            .outputMode("update") \
            .format("console") \
            .option("truncate", "false") \
            .option("numRows", "5") \
            .queryName("vitals_monitoring") \
            .trigger(processingTime="30 seconds") \
            .start()
        
        print("✓ Console monitoring started")
        print("  Window: 30 seconds")
        print("  Metrics: count, avg HR, avg BP, temperature, SpO2")
        
        return [console_query]
    
    def run_all_streams(self):
        """
        Start all streaming queries and wait.
        Blocks until interrupted (Ctrl+C).
        """
        print("\n" + "#"*60)
        print("# Starting ALL streaming pipelines")
        print("#"*60 + "\n")
        
        # Start all queries
        queries = []
        queries.extend(self.process_vitals_stream())
        queries.extend(self.process_adverse_events_stream())
        queries.extend(self.start_monitoring_console())
        
        print("\n" + "="*60)
        print("✅ All streams running")
        print("="*60)
        print("Press Ctrl+C to stop gracefully")
        print("Monitor progress in console output above")
        print("Check Spark UI at http://<driver-ip>:4040")
        print("="*60 + "\n")
        
        # Wait for all queries (blocks until interrupted)
        try:
            self.spark.streams.awaitAnyTermination()
        except KeyboardInterrupt:
            print("\n⏸️  Stopping streams...")
            for query in queries:
                query.stop()
            print("✅ All streams stopped gracefully")


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    """Main entry point for streaming processor."""
    # Get configuration from environment
    kafka_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:29092")
    s3_bucket = os.getenv("S3_BUCKET", "clinical-mlops")
    
    print("\n" + "="*60)
    print("Clinical MLOps - Streaming Processor")
    print("="*60)
    print(f"Kafka Brokers: {kafka_servers}")
    print(f"S3 Bucket: {s3_bucket}")
    print(f"Processing Mode: Real-time streaming")
    print(f"Topics: patient-vitals, adverse-events")
    print("="*60 + "\n")
    
    # Create Spark session
    spark = create_spark_session("StreamingProcessor")
    
    # Create processor
    processor = StreamingProcessor(spark, kafka_servers, s3_bucket)
    processor = StreamingProcessor(spark, kafka_servers, s3_bucket)
    
    # Run all streams (blocks until interrupted)
    processor.run_all_streams()
    
    # Cleanup
    spark.stop()
    print("\n✅ Streaming processor terminated")


if __name__ == "__main__":
    main()