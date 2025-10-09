"""
Data standardization transformations.
Enriches data with derived metrics and standardizes formats.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import (
    col, when, lit, round as spark_round,
    to_date, hour as spark_hour, upper
)


def standardize_vitals(df: DataFrame) -> DataFrame:
    """
    Standardize and enrich vital signs data.
    
    Enrichments:
    - Pulse pressure (systolic - diastolic)
    - Mean arterial pressure (MAP)
    - Abnormal flags
    - Processing date/hour for partitioning
    
    Args:
        df: Input DataFrame with vitals
        
    Returns:
        Enriched DataFrame
    """
    enriched = df \
        .withColumn(
            "pulse_pressure",
            col("blood_pressure_systolic") - col("blood_pressure_diastolic")
        ) \
        .withColumn(
            "mean_arterial_pressure",
            spark_round(
                (col("blood_pressure_systolic") + 2 * col("blood_pressure_diastolic")) / 3,
                1
            )
        ) \
        .withColumn(
            "is_tachycardia",
            col("heart_rate") > 100
        ) \
        .withColumn(
            "is_bradycardia",
            col("heart_rate") < 60
        ) \
        .withColumn(
            "is_hypertensive",
            (col("blood_pressure_systolic") >= 140) | (col("blood_pressure_diastolic") >= 90)
        ) \
        .withColumn(
            "is_hypotensive",
            (col("blood_pressure_systolic") < 90) | (col("blood_pressure_diastolic") < 60)
        ) \
        .withColumn(
            "is_febrile",
            col("temperature") >= 38.0
        ) \
        .withColumn(
            "is_hypothermic",
            col("temperature") < 36.0
        ) \
        .withColumn(
            "is_hypoxic",
            col("spo2") < 95
        ) \
        .withColumn(
            "processing_date",
            to_date(col("timestamp"))
        ) \
        .withColumn(
            "processing_hour",
            spark_hour(col("timestamp"))
        ) \
        .withColumn(
            "source",
            upper(col("source"))
        )
    
    return enriched


def standardize_lab_results(df: DataFrame) -> DataFrame:
    """
    Standardize lab results.
    
    Enrichments:
    - Abnormal flag (outside reference range)
    - Processing date for partitioning
    
    Args:
        df: Input DataFrame with lab results
        
    Returns:
        Enriched DataFrame
    """
    enriched = df \
        .withColumn(
            "processing_date",
            to_date(col("timestamp"))
        ) \
        .withColumn(
            "processing_hour",
            spark_hour(col("timestamp"))
        ) \
        .withColumn(
            "test_name",
            upper(col("test_name"))
        )
    
    return enriched


def standardize_medications(df: DataFrame) -> DataFrame:
    """
    Standardize medication records.
    
    Enrichments:
    - Processing date for partitioning
    - Uppercase drug names
    
    Args:
        df: Input DataFrame with medications
        
    Returns:
        Enriched DataFrame
    """
    enriched = df \
        .withColumn(
            "processing_date",
            to_date(col("timestamp"))
        ) \
        .withColumn(
            "processing_hour",
            spark_hour(col("timestamp"))
        ) \
        .withColumn(
            "drug_name",
            upper(col("drug_name"))
        ) \
        .withColumn(
            "route",
            upper(col("route"))
        )
    
    return enriched


def standardize_adverse_events(df: DataFrame) -> DataFrame:
    """
    Standardize adverse event records.
    
    Enrichments:
    - Processing date for partitioning
    - Severity numeric value
    - Uppercase event type
    
    Args:
        df: Input DataFrame with adverse events
        
    Returns:
        Enriched DataFrame
    """
    enriched = df \
        .withColumn(
            "processing_date",
            to_date(col("event_timestamp"))
        ) \
        .withColumn(
            "processing_hour",
            spark_hour(col("event_timestamp"))
        ) \
        .withColumn(
            "severity_numeric",
            when(col("severity") == "grade_1", 1)
            .when(col("severity") == "grade_2", 2)
            .when(col("severity") == "grade_3", 3)
            .when(col("severity") == "grade_4", 4)
            .otherwise(0)
        ) \
        .withColumn(
            "event_type",
            upper(col("event_type"))
        )
    
    return enriched