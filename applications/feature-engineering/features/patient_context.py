"""
Patient context feature generation.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import (
    col, lit, when, datediff, current_date
)
from typing import Dict, List


class PatientContextGenerator:
    """
    Generate patient context features (demographics, trial info).
    """
    
    def __init__(self, config: Dict):
        """
        Initialize with feature configuration.
        
        Args:
            config: Feature configuration dictionary
        """
        self.config = config
        self.context_config = config['feature_groups']['patient_context']
        
        print(f"✓ Initialized PatientContextGenerator")
    
    def generate_features(self, df: DataFrame) -> DataFrame:
        """
        Generate patient context features.
        
        Args:
            df: Input DataFrame with patient data
            
        Returns:
            DataFrame with context features
        """
        print(f"\n{'='*60}")
        print("Generating Patient Context Features")
        print(f"{'='*60}")
        
        result_df = df
        feature_count = 0
        
        # Days since enrollment (using first record as proxy)
        # In production, this would come from enrollment database
        result_df = result_df.withColumn(
            "days_since_enrollment",
            datediff(current_date(), col("timestamp"))
        )
        feature_count += 1
        print(f"  ✓ Generated days_since_enrollment")
        
        # Encode trial_arm (if exists)
        if "trial_arm" in df.columns:
            result_df = result_df.withColumn(
                "trial_arm_encoded",
                when(col("trial_arm") == "treatment", 1)
                .when(col("trial_arm") == "control", 0)
                .otherwise(-1)
            )
            feature_count += 1
            print(f"  ✓ Generated trial_arm_encoded")
        
        # Encode trial_site (if exists) - using hash for simplicity
        if "trial_site" in df.columns:
            result_df = result_df.withColumn(
                "trial_site_encoded",
                col("trial_site").cast("int")
            )
            feature_count += 1
            print(f"  ✓ Generated trial_site_encoded")
        
        print(f"\n  ✓ Generated {feature_count} context features")
        return result_df
    
    def get_feature_names(self) -> List[str]:
        """Get list of all context feature names."""
        return [
            "days_since_enrollment",
            "trial_arm_encoded",
            "trial_site_encoded"
        ]