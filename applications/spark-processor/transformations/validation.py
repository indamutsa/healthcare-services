"""
Data validation transformations.
Validates records against business rules and physiological ranges.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import col, when, lit, concat_ws, array


def validate_vitals(df: DataFrame) -> DataFrame:
    """
    Validate patient vitals against physiological ranges.
    
    Validation Rules:
    - Heart rate: 40-200 bpm
    - BP systolic: 60-250 mmHg
    - BP diastolic: 40-150 mmHg
    - Temperature: 35.0-42.0 °C
    - SpO2: 70-100 %
    - Required fields present
    
    Args:
        df: Input DataFrame with vitals
        
    Returns:
        DataFrame with is_valid and validation_failure columns
    """
    validated = df.withColumn(
        "is_valid",
        (col("patient_id").isNotNull()) &
        (col("timestamp").isNotNull()) &
        (col("heart_rate").isNotNull()) &
        (col("heart_rate").between(40, 200)) &
        (col("blood_pressure_systolic").isNotNull()) &
        (col("blood_pressure_systolic").between(60, 250)) &
        (col("blood_pressure_diastolic").isNotNull()) &
        (col("blood_pressure_diastolic").between(40, 150)) &
        (col("temperature").isNotNull()) &
        (col("temperature").between(35.0, 42.0)) &
        (col("spo2").isNotNull()) &
        (col("spo2").between(70, 100))
    )
    
    # Build validation failure message
    validated = validated.withColumn(
        "validation_failure",
        when(~col("is_valid"),
            concat_ws("; ",
                array(
                    when(col("patient_id").isNull(), lit("missing_patient_id")),
                    when(col("timestamp").isNull(), lit("missing_timestamp")),
                    when(~col("heart_rate").between(40, 200), lit("invalid_heart_rate")),
                    when(~col("blood_pressure_systolic").between(60, 250), lit("invalid_bp_systolic")),
                    when(~col("blood_pressure_diastolic").between(40, 150), lit("invalid_bp_diastolic")),
                    when(~col("temperature").between(35.0, 42.0), lit("invalid_temperature")),
                    when(~col("spo2").between(70, 100), lit("invalid_spo2"))
                )
            )
        )
    )
    
    return validated


def validate_lab_results(df: DataFrame) -> DataFrame:
    """
    Validate lab results.
    
    Validation Rules:
    - Required fields present
    - Value is numeric and positive
    
    Args:
        df: Input DataFrame with lab results
        
    Returns:
        DataFrame with is_valid and validation_failure columns
    """
    validated = df.withColumn(
        "is_valid",
        (col("patient_id").isNotNull()) &
        (col("timestamp").isNotNull()) &
        (col("test_name").isNotNull()) &
        (col("value").isNotNull()) &
        (col("value") > 0)
    )
    
    validated = validated.withColumn(
        "validation_failure",
        when(~col("is_valid"), lit("missing_required_fields_or_invalid_value"))
    )
    
    return validated


def validate_medications(df: DataFrame) -> DataFrame:
    """
    Validate medication records.
    
    Validation Rules:
    - Required fields present
    - Dosage is positive
    
    Args:
        df: Input DataFrame with medications
        
    Returns:
        DataFrame with is_valid and validation_failure columns
    """
    validated = df.withColumn(
        "is_valid",
        (col("patient_id").isNotNull()) &
        (col("timestamp").isNotNull()) &
        (col("drug_name").isNotNull()) &
        (col("dosage").isNotNull()) &
        (col("dosage") > 0)
    )
    
    validated = validated.withColumn(
        "validation_failure",
        when(~col("is_valid"), lit("missing_required_fields_or_invalid_dosage"))
    )
    
    return validated


def validate_adverse_events(df: DataFrame) -> DataFrame:
    """
    Validate adverse event records.
    
    Validation Rules:
    - Required fields present
    - Severity is valid grade
    
    Args:
        df: Input DataFrame with adverse events
        
    Returns:
        DataFrame with is_valid and validation_failure columns
    """
    valid_severities = ["grade_1", "grade_2", "grade_3", "grade_4"]
    
    validated = df.withColumn(
        "is_valid",
        (col("patient_id").isNotNull()) &
        (col("event_timestamp").isNotNull()) &
        (col("event_type").isNotNull()) &
        (col("severity").isNotNull()) &
        (col("severity").isin(valid_severities))
    )
    
    validated = validated.withColumn(
        "validation_failure",
        when(~col("is_valid"), lit("missing_required_fields_or_invalid_severity"))
    )
    
    return validated