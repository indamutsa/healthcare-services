#!/bin/bash
#
# Visualize Features from Feature Store
# Creates summary statistics and distributions
#

set -e

echo "=========================================="
echo "Feature Visualization"
echo "=========================================="
echo ""

# Configuration
DATE=${1:-$(date -u -d "yesterday" +%Y-%m-%d)}
OUTPUT_DIR="./visualizations"
BUCKET_NAME="clinical-mlops"

mkdir -p "$OUTPUT_DIR"

echo "Processing date: $DATE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create Python script for visualization
cat > /tmp/visualize_features.py << 'EOF'
import sys
import pandas as pd
import numpy as np
from datetime import datetime
import json

# Spark session
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("FeatureVisualization") \
    .config("spark.jars.packages", "org.apache.hadoop:hadoop-aws:3.3.4") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
    .getOrCreate()

date = sys.argv[1]
output_dir = sys.argv[2]

print(f"\nLoading features for date: {date}")
print(f"Output directory: {output_dir}\n")

# Load features
feature_path = f"s3a://clinical-mlops/features/offline/date={date}/"
df = spark.read.parquet(feature_path)

print(f"✓ Loaded {df.count():,} records")
print(f"✓ Columns: {len(df.columns)}\n")

# Get feature columns
exclude_cols = ['patient_id', 'timestamp', 'processing_date', 'processed_at', 
                'feature_version', 'adverse_event_24h', 'source', 'trial_site', 'trial_arm']
feature_cols = [c for c in df.columns if c not in exclude_cols]

print(f"✓ Feature columns: {len(feature_cols)}\n")

# Convert to pandas for analysis (sample if too large)
sample_size = min(10000, df.count())
pdf = df.sample(fraction=sample_size/df.count()).toPandas()

print(f"✓ Sampled {len(pdf):,} records for analysis\n")

# 1. Feature Statistics
print("="*60)
print("Feature Statistics")
print("="*60)

stats = []
for col in feature_cols:
    try:
        col_data = pdf[col].dropna()
        if len(col_data) > 0:
            stat = {
                'feature': col,
                'count': int(len(col_data)),
                'missing': int(pdf[col].isna().sum()),
                'missing_pct': float(pdf[col].isna().sum() / len(pdf) * 100),
                'mean': float(col_data.mean()) if np.issubdtype(col_data.dtype, np.number) else None,
                'std': float(col_data.std()) if np.issubdtype(col_data.dtype, np.number) else None,
                'min': float(col_data.min()) if np.issubdtype(col_data.dtype, np.number) else None,
                'max': float(col_data.max()) if np.issubdtype(col_data.dtype, np.number) else None,
                'median': float(col_data.median()) if np.issubdtype(col_data.dtype, np.number) else None
            }
            stats.append(stat)
    except Exception as e:
        print(f"  ✗ Error processing {col}: {e}")

# Save statistics
stats_df = pd.DataFrame(stats)
stats_file = f"{output_dir}/feature_statistics_{date}.csv"
stats_df.to_csv(stats_file, index=False)
print(f"\n✓ Saved statistics to: {stats_file}")

# Print top 20 features by mean value
print("\nTop 20 features by mean value:")
print(stats_df.nlargest(20, 'mean')[['feature', 'mean', 'std', 'missing_pct']])

# 2. Feature Groups Summary
print("\n" + "="*60)
print("Feature Groups Summary")
print("="*60)

groups = {
    'temporal_vitals': [c for c in feature_cols if any(x in c for x in ['heart_rate', 'bp_', 'temperature', 'spo2'])],
    'lab_results': [c for c in feature_cols if c.startswith('lab_')],
    'medications': [c for c in feature_cols if any(x in c for x in ['medication', 'drug_', 'high_risk'])],
    'patient_context': [c for c in feature_cols if any(x in c for x in ['days_since', 'trial_'])],
    'derived': [c for c in feature_cols if any(x in c for x in ['score', 'proxy', 'interaction'])]
}

group_summary = []
for group_name, group_cols in groups.items():
    group_summary.append({
        'group': group_name,
        'feature_count': len(group_cols),
        'avg_missing_pct': stats_df[stats_df['feature'].isin(group_cols)]['missing_pct'].mean()
    })

group_df = pd.DataFrame(group_summary)
print(group_df)

# 3. Label Distribution
print("\n" + "="*60)
print("Label Distribution")
print("="*60)

if 'adverse_event_24h' in pdf.columns:
    label_counts = pdf['adverse_event_24h'].value_counts()
    total = len(pdf)
    
    print(f"Negative (0): {label_counts.get(0, 0):,} ({label_counts.get(0, 0)/total*100:.2f}%)")
    print(f"Positive (1): {label_counts.get(1, 0):,} ({label_counts.get(1, 0)/total*100:.2f}%)")
    
    # Save label distribution
    label_file = f"{output_dir}/label_distribution_{date}.json"
    with open(label_file, 'w') as f:
        json.dump({
            'date': date,
            'total_samples': int(total),
            'negative_count': int(label_counts.get(0, 0)),
            'positive_count': int(label_counts.get(1, 0)),
            'positive_rate': float(label_counts.get(1, 0)/total*100)
        }, f, indent=2)
    print(f"\n✓ Saved label distribution to: {label_file}")

# 4. Missing Data Report
print("\n" + "="*60)
print("Missing Data Report")
print("="*60)

high_missing = stats_df[stats_df['missing_pct'] > 10].sort_values('missing_pct', ascending=False)
if len(high_missing) > 0:
    print(f"\nFeatures with >10% missing data ({len(high_missing)}):")
    print(high_missing[['feature', 'missing_pct']].head(20))
else:
    print("\n✓ No features with >10% missing data")

# 5. Create summary report
print("\n" + "="*60)
print("Generating Summary Report")
print("="*60)

report = {
    'date': date,
    'timestamp': datetime.utcnow().isoformat(),
    'total_records': int(df.count()),
    'total_features': len(feature_cols),
    'feature_groups': group_df.to_dict('records'),
    'high_missing_features': int(len(high_missing)),
    'label_balance': {
        'negative': int(label_counts.get(0, 0)),
        'positive': int(label_counts.get(1, 0))
    } if 'adverse_event_24h' in pdf.columns else None
}

report_file = f"{output_dir}/summary_report_{date}.json"
with open(report_file, 'w') as f:
    json.dump(report, f, indent=2)

print(f"\n✓ Saved summary report to: {report_file}")

print("\n" + "="*60)
print("Visualization Complete!")
print("="*60)

spark.stop()
EOF

# Run visualization in Docker
echo "Running feature visualization..."
echo ""

docker run --rm \
    --network clinical-mlops_mlops-network \
    -v "$(pwd)/$OUTPUT_DIR:/output" \
    -v /tmp/visualize_features.py:/app/visualize.py \
    apache/spark:3.5.4-java17 \
    /bin/bash -c "
        pip install pandas numpy > /dev/null 2>&1 && \
        python /app/visualize.py '$DATE' /output
    "

echo ""
echo "=========================================="
echo "Output Files"
echo "=========================================="
ls -lh "$OUTPUT_DIR"/*${DATE}* 2>/dev/null || echo "No files generated"

echo ""
echo "✓ Visualization complete!"
echo "  Check the '$OUTPUT_DIR' directory for results"