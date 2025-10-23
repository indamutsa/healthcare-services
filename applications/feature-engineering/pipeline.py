"""
Feature Engineering Pipeline - Main Orchestration.
"""

import os
import sys
import yaml
from datetime import datetime, timedelta
from pyspark.sql.functions import col, lit, current_timestamp

# Import utilities
from utils.spark_session import create_feature_engineering_spark
from utils.feature_metadata import FeatureMetadata

# Import feature generators
from features import (
    TemporalFeatureGenerator,
    LabFeatureGenerator,
    MedicationFeatureGenerator,
    PatientContextGenerator,
    DerivedFeatureGenerator
)

# Import feature store
from feature_store import FeatureStore


class FeatureEngineeringPipeline:
    """
    Main feature engineering pipeline orchestrator.
    """
    
    def __init__(self, config_path: str):
        """
        Initialize pipeline with configuration.
        
        Args:
            config_path: Path to features.yaml
        """
        print("\n" + "="*60)
        print("Clinical MLOps - Feature Engineering Pipeline")
        print("="*60)
        
        # Load configuration
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        print(f"✓ Loaded configuration: {config_path}")
        print(f"  Feature version: {self.config['feature_version']}")
        
        # Create Spark session
        self.spark = create_feature_engineering_spark()
        
        # Get S3 bucket
        self.s3_bucket = os.getenv("S3_BUCKET", "clinical-mlops")
        
        # Initialize feature generators
        self.temporal_gen = TemporalFeatureGenerator(self.config)
        self.lab_gen = LabFeatureGenerator(self.config)
        self.med_gen = MedicationFeatureGenerator(self.config)
        self.context_gen = PatientContextGenerator(self.config)
        self.derived_gen = DerivedFeatureGenerator(self.config)
        
        # Initialize feature store
        self.feature_store = FeatureStore(self.config, self.spark)
        
        # Initialize metadata tracker
        self.metadata = FeatureMetadata()
        self.metadata.set_version(self.config['feature_version'])
        
        print("="*60 + "\n")
    
    def load_silver_data(self, date: str):
        """
        Load cleaned data from Silver layer.
        
        Args:
            date: Date string (YYYY-MM-DD)
            
        Returns:
            Tuple of DataFrames (vitals, adverse_events, labs, meds)
        """
        print(f"\n{'='*60}")
        print(f"Loading Silver Layer Data: {date}")
        print(f"{'='*60}")
        
        base_path = f"s3a://{self.s3_bucket}/processed"
        
        # Load patient vitals
        vitals_path = f"{base_path}/patient_vitals_stream/processing_date={date}/"
        print(f"  Loading vitals from: {vitals_path}")
        vitals_df = self.spark.read.parquet(vitals_path)
        vitals_count = vitals_df.count()
        print(f"    ✓ Loaded {vitals_count:,} vital records")
        
        # Load adverse events
        adverse_path = f"{base_path}/adverse_events_stream/processing_date={date}/"
        print(f"  Loading adverse events from: {adverse_path}")
        try:
            adverse_df = self.spark.read.parquet(adverse_path)
            adverse_count = adverse_df.count()
            print(f"    ✓ Loaded {adverse_count:,} adverse event records")
        except:
            print(f"    ⚠️  No adverse events found")
            adverse_df = None
        
        # Load lab results
        labs_path = f"{base_path}/lab_results/date={date}/"
        print(f"  Loading labs from: {labs_path}")
        try:
            labs_df = self.spark.read.parquet(labs_path)
            labs_count = labs_df.count()
            print(f"    ✓ Loaded {labs_count:,} lab records")
        except:
            print(f"    ⚠️  No lab results found")
            labs_df = None
        
        # Load medications
        meds_path = f"{base_path}/medications/date={date}/"
        print(f"  Loading medications from: {meds_path}")
        try:
            meds_df = self.spark.read.parquet(meds_path)
            meds_count = meds_df.count()
            print(f"    ✓ Loaded {meds_count:,} medication records")
        except:
            print(f"    ⚠️  No medications found")
            meds_df = None
        
        return vitals_df, adverse_df, labs_df, meds_df
    
    def generate_features(self, vitals_df, labs_df, meds_df):
        """
        Generate all features.
        
        Args:
            vitals_df: Vitals DataFrame
            labs_df: Labs DataFrame
            meds_df: Medications DataFrame
            
        Returns:
            DataFrame with all features
        """
        print(f"\n{'#'*60}")
        print("# FEATURE GENERATION")
        print(f"{'#'*60}")
        
        # Start with vitals (base dataset)
        features_df = vitals_df
        
        # 1. Temporal features
        features_df = self.temporal_gen.generate_features(features_df)
        
        # 2. Lab features
        if labs_df is not None:
            features_df = self.lab_gen.generate_features(features_df, labs_df)
        
        # 3. Medication features
        if meds_df is not None:
            features_df = self.med_gen.generate_features(features_df, meds_df)
        
        # 4. Patient context features
        features_df = self.context_gen.generate_features(features_df)
        
        # 5. Derived features
        features_df = self.derived_gen.generate_features(features_df)
        
        # Add processing metadata
        features_df = features_df \
            .withColumn("processed_at", current_timestamp()) \
            .withColumn("feature_version", lit(self.config['feature_version']))
        
        return features_df
    
    def create_labels(self, features_df, adverse_df):
        """
        Create labels for ML training.
        
        Args:
            features_df: Features DataFrame
            adverse_df: Adverse events DataFrame
            
        Returns:
            DataFrame with labels
        """
        if adverse_df is None:
            print("\n⚠️  No adverse events data - skipping label creation")
            return features_df.withColumn("adverse_event_24h", lit(0))
        
        print(f"\n{'='*60}")
        print("Creating Labels")
        print(f"{'='*60}")
        
        # Get prediction window
        window_hours = self.config['label']['prediction_window_hours']
        
        print(f"  Prediction window: {window_hours} hours")
        
        # Create labels based on adverse events in next 24 hours
        # Simplified: just flag if any adverse event exists for patient
        patients_with_events = adverse_df \
            .select("patient_id") \
            .distinct() \
            .withColumn("adverse_event_24h", lit(1))
        
        # Join with features
        labeled_df = features_df.join(
            patients_with_events,
            "patient_id",
            "left"
        ).fillna({"adverse_event_24h": 0})
        
        positive_count = labeled_df.filter(col("adverse_event_24h") == 1).count()
        total_count = labeled_df.count()
        positive_rate = (positive_count / total_count * 100) if total_count > 0 else 0
        
        print(f"  ✓ Positive labels: {positive_count:,} ({positive_rate:.2f}%)")
        print(f"  ✓ Negative labels: {total_count - positive_count:,}")
        
        return labeled_df
    
    def track_metadata(self, features_df):
        """
        Track feature metadata.
        
        Args:
            features_df: Features DataFrame
        """
        print(f"\n{'='*60}")
        print("Tracking Feature Metadata")
        print(f"{'='*60}")
        
        # Get all feature columns
        exclude_cols = ['patient_id', 'timestamp', 'processing_date', 
                       'processed_at', 'feature_version', 'adverse_event_24h',
                       'source', 'trial_site', 'trial_arm']
        
        feature_cols = [c for c in features_df.columns if c not in exclude_cols]
        
        # Register each feature
        for col_name in feature_cols:
            dtype = str(features_df.schema[col_name].dataType)
            
            # Determine source
            if col_name.startswith('heart_rate') or col_name.startswith('bp_') or \
               col_name.startswith('temperature') or col_name.startswith('spo2'):
                source = "patient_vitals_stream"
            elif col_name.startswith('lab_'):
                source = "lab_results"
            elif col_name.startswith('current_medication') or col_name.startswith('high_risk') or \
                 col_name.startswith('drug_') or col_name.startswith('days_on'):
                source = "medications"
            elif col_name.startswith('days_since') or col_name.startswith('trial_'):
                source = "patient_context"
            else:
                source = "derived"
            
            self.metadata.add_feature(
                name=col_name,
                dtype=dtype,
                description=f"Feature: {col_name}",
                source=source,
                computation="Generated by feature engineering pipeline"
            )
        
        # Print summary
        summary = self.metadata.summary()
        print(f"\n  Total features: {summary['total_features']}")
        print(f"  By source:")
        for source, count in summary['by_source'].items():
            print(f"    - {source}: {count}")
        
        # Save metadata
        metadata_path = "/app/data/feature_metadata.json"
        self.metadata.save(metadata_path)
    
    def run(self, date: str):
        """
        Run full feature engineering pipeline for a given date.
        
        Args:
            date: Date string (YYYY-MM-DD)
        """
        start_time = datetime.utcnow()
        
        print(f"\n{'#'*60}")
        print(f"# Running Pipeline for: {date}")
        print(f"{'#'*60}\n")
        
        try:
            # 1. Load silver data
            vitals_df, adverse_df, labs_df, meds_df = self.load_silver_data(date)
            
            # 2. Generate features
            features_df = self.generate_features(vitals_df, labs_df, meds_df)
            
            # 3. Create labels
            labeled_df = self.create_labels(features_df, adverse_df)
            
            # 4. Write to offline store
            self.feature_store.write_offline(labeled_df, date)
            
            # 5. Update online store
            self.feature_store.update_online(labeled_df)
            
            # 6. Track metadata
            self.track_metadata(labeled_df)
            
            # Print summary
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            print(f"\n{'='*60}")
            print("PIPELINE COMPLETE")
            print(f"{'='*60}")
            print(f"Date: {date}")
            print(f"Duration: {duration:.2f} seconds")
            print(f"Status: SUCCESS ✓")
            print(f"{'='*60}\n")
            
        except Exception as e:
            print(f"\n{'='*60}")
            print("PIPELINE FAILED")
            print(f"{'='*60}")
            print(f"Error: {e}")
            print(f"{'='*60}\n")
            raise
        
        finally:
            self.spark.stop()


def main():
    """Main entry point."""
    # Get date from environment or use yesterday
    date_str = os.getenv("PROCESS_DATE")
    
    if not date_str:
        yesterday = datetime.utcnow() - timedelta(days=1)
        date_str = yesterday.strftime("%Y-%m-%d")
    
    print(f"\nProcessing date: {date_str}\n")
    
    # Run pipeline
    pipeline = FeatureEngineeringPipeline("/app/config/features.yaml")
    pipeline.run(date_str)


if __name__ == "__main__":
    main()