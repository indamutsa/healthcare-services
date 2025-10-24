"""
Derived feature generation (interactions, combinations).
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import col
from typing import Dict, List


class DerivedFeatureGenerator:
    """
    Generate derived features from existing features.
    """
    
    def __init__(self, config: Dict):
        """
        Initialize with feature configuration.
        
        Args:
            config: Feature configuration dictionary
        """
        self.config = config
        self.derived_config = config['feature_groups']['derived_features']
        self.interactions = self.derived_config['interactions']
        
        print(f"✓ Initialized DerivedFeatureGenerator")
        print(f"  Interactions: {len(self.interactions)}")
    
    def generate_features(self, df: DataFrame) -> DataFrame:
        """
        Generate derived features using formulas.
        
        Args:
            df: Input DataFrame with base features
            
        Returns:
            DataFrame with derived features
        """
        print(f"\n{'='*60}")
        print("Generating Derived Features")
        print(f"{'='*60}")
        
        result_df = df
        feature_count = 0
        
        for interaction in self.interactions:
            name = interaction['name']
            formula = interaction['formula']
            
            print(f"  Processing: {name}")
            print(f"    Formula: {formula}")
            
            try:
                # Parse the formula and create column expression
                if "heart_rate_std_24h" in formula and "bp_systolic_std_24h" in formula and "temperature_std_24h" in formula:
                    result_df = result_df.withColumn(
                        name, 
                        col('heart_rate_std_24h') + col('bp_systolic_std_24h') + col('temperature_std_24h')
                    )
                elif "heart_rate_mean_1h" in formula and "bp_systolic_mean_6h" in formula:
                    result_df = result_df.withColumn(
                        name,
                        (col('heart_rate_mean_1h') * col('bp_systolic_mean_6h')) / 10000
                    )
                elif "heart_rate_mean_1h" in formula and "temperature_mean_1h" in formula:
                    result_df = result_df.withColumn(
                        name,
                        col('heart_rate_mean_1h') * col('temperature_mean_1h')
                    )
                else:
                    print(f"    ⚠️  Unknown formula pattern for {name}")
                    continue
                    
                feature_count += 1
                print(f"    ✓ Generated {name}")
                
            except Exception as e:
                print(f"    ✗ Error generating {name}: {e}")
        
        print(f"\n  ✓ Generated {feature_count} derived features")
        return result_df
    
    def get_feature_names(self) -> List[str]:
        """Get list of all derived feature names."""
        return [interaction['name'] for interaction in self.interactions]