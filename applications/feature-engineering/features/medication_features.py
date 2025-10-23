"""
Medication feature generation.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import (
    col, lit, when, count, max as spark_max, datediff, current_date,
    collect_set, array_contains
)
from pyspark.sql.window import Window
from typing import Dict, List


class MedicationFeatureGenerator:
    """
    Generate features from medication data.
    """
    
    def __init__(self, config: Dict):
        """
        Initialize with feature configuration.
        
        Args:
            config: Feature configuration dictionary
        """
        self.config = config
        self.med_config = config['feature_groups']['medications']
        self.high_risk_drugs = self.med_config['high_risk_drugs']
        
        print(f"✓ Initialized MedicationFeatureGenerator")
        print(f"  High-risk drugs: {len(self.high_risk_drugs)}")
    
    def generate_features(self, vitals_df: DataFrame, meds_df: DataFrame) -> DataFrame:
        """
        Generate medication-based features.
        
        Args:
            vitals_df: Patient vitals DataFrame (for timestamps)
            meds_df: Medications DataFrame
            
        Returns:
            DataFrame with medication features
        """
        print(f"\n{'='*60}")
        print("Generating Medication Features")
        print(f"{'='*60}")
        
        result_df = vitals_df
        feature_count = 0
        
        # Current medication count (active in last 24 hours)
        current_meds = meds_df \
            .filter(datediff(current_date(), col("timestamp")) <= 1) \
            .groupBy("patient_id") \
            .agg(count("drug_name").alias("current_medication_count"))
        
        result_df = result_df.join(current_meds, "patient_id", "left") \
            .fillna({"current_medication_count": 0})
        
        feature_count += 1
        print(f"  ✓ Generated current_medication_count")
        
        # High-risk drug flag
        high_risk_meds = meds_df \
            .filter(datediff(current_date(), col("timestamp")) <= 1) \
            .filter(col("drug_name").isin(self.high_risk_drugs)) \
            .groupBy("patient_id") \
            .agg(lit(1).alias("high_risk_drug_flag")) \
            .select("patient_id", "high_risk_drug_flag")
        
        result_df = result_df.join(high_risk_meds, "patient_id", "left") \
            .fillna({"high_risk_drug_flag": 0})
        
        feature_count += 1
        print(f"  ✓ Generated high_risk_drug_flag")
        
        # Drug interaction flag (simplified - 2+ high-risk drugs)
        interaction_flag = meds_df \
            .filter(datediff(current_date(), col("timestamp")) <= 1) \
            .filter(col("drug_name").isin(self.high_risk_drugs)) \
            .groupBy("patient_id") \
            .agg(count("drug_name").alias("high_risk_count")) \
            .withColumn(
                "drug_interaction_flag",
                when(col("high_risk_count") >= 2, 1).otherwise(0)
            ) \
            .select("patient_id", "drug_interaction_flag")
        
        result_df = result_df.join(interaction_flag, "patient_id", "left") \
            .fillna({"drug_interaction_flag": 0})
        
        feature_count += 1
        print(f"  ✓ Generated drug_interaction_flag")
        
        # Days on current medication (most recent med)
        window_spec = Window.partitionBy("patient_id").orderBy(col("timestamp").desc())
        
        days_on_med = meds_df \
            .withColumn("row_num", row_number().over(window_spec)) \
            .filter(col("row_num") == 1) \
            .withColumn(
                "days_on_current_med",
                datediff(current_date(), col("timestamp"))
            ) \
            .select("patient_id", "days_on_current_med")
        
        result_df = result_df.join(days_on_med, "patient_id", "left") \
            .fillna({"days_on_current_med": 0})
        
        feature_count += 1
        print(f"  ✓ Generated days_on_current_med")
        
        print(f"\n  ✓ Generated {feature_count} medication features")
        return result_df
    
    def get_feature_names(self) -> List[str]:
        """Get list of all medication feature names."""
        return [
            "current_medication_count",
            "high_risk_drug_flag",
            "drug_interaction_flag",
            "days_on_current_med"
        ]


# Import row_number
from pyspark.sql.functions import row_number