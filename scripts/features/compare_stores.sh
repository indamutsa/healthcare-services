#!/bin/bash
#
# Compare online and offline feature stores
# Checks consistency and synchronization
#

set -e

echo "=========================================="
echo "Feature Store Comparison"
echo "=========================================="
echo ""

DATE=${1:-$(date -u -d "yesterday" +%Y-%m-%d)}

echo "Comparing stores for date: $DATE"
echo ""

# Get patient count from offline store
echo "1. Offline Store (MinIO)"
echo "------------------------------------------"

cat > /tmp/count_offline.py << EOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("CountOffline") \
    .config("spark.jars.packages", "org.apache.hadoop:hadoop-aws:3.3.4") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
    .getOrCreate()

spark.sparkContext.setLogLevel("ERROR")

try:
    df = spark.read.parquet("s3a://clinical-mlops/features/offline/date=$DATE/")
    patient_count = df.select("patient_id").distinct().count()
    total_records = df.count()
    feature_count = len(df.columns)
    
    print(f"Patients: {patient_count:,}")
    print(f"Records: {total_records:,}")
    print(f"Features: {feature_count}")
    
    # Save for comparison
    with open("/tmp/offline_count.txt", "w") as f:
        f.write(str(patient_count))
        
except Exception as e:
    print(f"Error: {e}")
    with open("/tmp/offline_count.txt", "w") as f:
        f.write("0")

spark.stop()
EOF

docker run --rm \
    --network clinical-mlops_mlops-network \
    -v /tmp/count_offline.py:/app/count.py \
    -v /tmp:/tmp \
    apache/spark:3.5.4-java17 \
    python /app/count.py

OFFLINE_COUNT=$(cat /tmp/offline_count.txt 2>/dev/null || echo "0")

echo ""
echo "2. Online Store (Redis)"
echo "------------------------------------------"

ONLINE_COUNT=$(docker exec redis redis-cli --scan --pattern "patient:*:features" | wc -l)

echo "Patients: $ONLINE_COUNT"

# Compare
echo ""
echo "3. Comparison"
echo "------------------------------------------"

echo "Offline patients: $OFFLINE_COUNT"
echo "Online patients:  $ONLINE_COUNT"

DIFF=$((OFFLINE_COUNT - ONLINE_COUNT))

if [ "$DIFF" -eq 0 ]; then
    echo "✓ Stores are synchronized"
elif [ "$DIFF" -gt 0 ]; then
    echo "⚠️  Offline has $DIFF more patients than online"
    echo "   This is normal if online store has TTL expiration"
else
    DIFF=$((DIFF * -1))
    echo "⚠️  Online has $DIFF more patients than offline"
    echo "   This indicates stale data in online store"
fi

echo ""
echo "=========================================="