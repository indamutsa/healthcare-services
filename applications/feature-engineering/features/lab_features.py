"""
Lab result feature generation.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import (
    col, lit, when, coalesce, last, datediff, current_date, count
)
from pyspark.sql.window import Window
from typing import Dict, List


class LabFeatureGenerator:
    """
    Generate features from lab test results.
    """
    
    def __init__(self, config: Dict):
        """
        Initialize with feature configuration.
        
        Args:
            config: Feature configuration dictionary
        """
        self.config = config
        self.lab_config = config['feature_groups']['lab_results']
        self.tests = self.lab_config['tests']
        
        print(f"✓ Initialized LabFeatureGenerator")
        print(f"  Tracking {len(self.tests)} lab tests")
    
    def generate_features(self, vitals_df: DataFrame, labs_df: DataFrame) -> DataFrame:
        """
        Generate lab-based features.
        
        Args:
            vitals_df: Patient vitals DataFrame (for timestamps)
            labs_df: Lab results DataFrame
            
        Returns:
            DataFrame with lab features
        """
        print(f"\n{'='*60}")
        print("Generating Lab Features")
        print(f"{'='*60}")
        
        result_df = vitals_df
        
        # Create window for getting latest lab value per patient per test
        latest_window = Window \
            .partitionBy("patient_id", "test_name") \
            .orderBy(col("timestamp").desc())
        
        # Get baseline (first ever) lab values
        baseline_window = Window \
            .partitionBy("patient_id", "test_name") \
            .orderBy(col("timestamp").asc())
        
        # Add baseline values
        labs_with_baseline = labs_df \
            .withColumn("baseline_value", last("value", ignorenulls=True).over(baseline_window))
        
        feature_count = 0
        
        # Generate features for each test
        for test in self.tests:
            print(f"\n  Processing test: {test}")
            
            # Filter to specific test
            test_df = labs_with_baseline.filter(col("test_name") == test)
            
            # Latest value
            latest_feature = f"lab_{test}_latest"
            test_latest = test_df \
                .withColumn("row_num", row_number().over(latest_window)) \
                .filter(col("row_num") == 1) \
                .select("patient_id", col("value").alias(latest_feature))
            
            result_df = result_df.join(test_latest, "patient_id", "left")
            feature_count += 1
            
            # Change from baseline
            change_feature = f"lab_{test}_change_from_baseline"
            test_change = test_df \
                .withColumn("row_num", row_number().over(latest_window)) \
                .filter(col("row_num") == 1) \
                .withColumn(
                    change_feature,
                    col("value") - col("baseline_value")
                ) \
                .select("patient_id", change_feature)
            
            result_df = result_df.join(test_change, "patient_id", "left")
            feature_count += 1
            
            # Days since last test
            days_feature = f"lab_{test}_days_since_last"
            test_days = test_df \
                .withColumn("row_num", row_number().over(latest_window)) \
                .filter(col("row_num") == 1) \
                .withColumn(
                    days_feature,
                    datediff(current_date(), col("timestamp"))
                ) \
                .select("patient_id", days_feature)
            
            result_df = result_df.join(test_days, "patient_id", "left")
            feature_count += 1
        
        # Abnormal count in last 7 days
        abnormal_count_feature = "lab_abnormal_count_7d"
        
        # Define abnormal ranges (simplified - in production, use reference ranges)
        abnormal_conditions = (
            ((col("test_name") == "ALT") & ((col("value") < 7) | (col("value") > 56))) |
            ((col("test_name") == "AST") & ((col("value") < 10) | (col("value") > 40))) |
            ((col("test_name") == "creatinine") & ((col("value") < 0.6) | (col("value") > 1.2)))
            # Add more conditions for other tests
        )
        
        abnormal_df = labs_df \
            .filter(datediff(current_date(), col("timestamp")) <= 7) \
            .filter(abnormal_conditions) \
            .groupBy("patient_id") \
            .agg(count("*").alias(abnormal_count_feature))
        
        result_df = result_df.join(abnormal_df, "patient_id", "left") \
            .fillna({abnormal_count_feature: 0})
        
        feature_count += 1
        
        print(f"\n  ✓ Generated {feature_count} lab features")
        return result_df
    
    def get_feature_names(self) -> List[str]:
        """Get list of all lab feature names."""
        features = []
        
        for test in self.tests:
            features.extend([
                f"lab_{test}_latest",
                f"lab_{test}_change_from_baseline",
                f"lab_{test}_days_since_last"
            ])
        
        features.append("lab_abnormal_count_7d")
        
        return features


# Import row_number
from pyspark.sql.functions import row_number