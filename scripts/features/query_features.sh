#!/bin/bash
#
# Query features for a specific patient
# Retrieves from both offline and online stores
#

set -e

PATIENT_ID=${1:-""}
DATE=${2:-$(date -u -d "yesterday" +%Y-%m-%d)}

if [ -z "$PATIENT_ID" ]; then
    echo "Usage: $0 <patient_id> [date]"
    echo ""
    echo "Example: $0 PT00042 2025-10-07"
    exit 1
fi

echo "=========================================="
echo "Feature Query for Patient: $PATIENT_ID"
echo "=========================================="
echo ""

# Query online store (Redis)
echo "1. Online Feature Store (Redis)"
echo "------------------------------------------"

REDIS_KEY="patient:${PATIENT_ID}:features"

echo "Checking Redis key: $REDIS_KEY"
echo ""

EXISTS=$(docker exec redis redis-cli exists "$REDIS_KEY")

if [ "$EXISTS" -eq 1 ]; then
    echo "✓ Patient found in online store"
    echo ""
    echo "Features:"
    docker exec redis redis-cli hgetall "$REDIS_KEY"
    echo ""
    
    # Get TTL
    TTL=$(docker exec redis redis-cli ttl "$REDIS_KEY")
    TTL_HOURS=$((TTL / 3600))
    echo "TTL: ${TTL}s (${TTL_HOURS}h remaining)"
else
    echo "✗ Patient not found in online store"
fi

echo ""
echo "2. Offline Feature Store (MinIO)"
echo "------------------------------------------"

# Create query script
cat > /tmp/query_offline.py << EOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("QueryOffline") \
    .config("spark.jars.packages", "org.apache.hadoop:hadoop-aws:3.3.4") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
    .getOrCreate()

spark.sparkContext.setLogLevel("ERROR")

patient_id = "$PATIENT_ID"
date = "$DATE"

print(f"Querying patient: {patient_id} for date: {date}")

try:
    feature_path = f"s3a://clinical-mlops/features/offline/date={date}/"
    df = spark.read.parquet(feature_path)
    
    patient_df = df.filter(df.patient_id == patient_id)
    count = patient_df.count()
    
    if count > 0:
        print(f"✓ Found {count} records for patient")
        print("\nLatest record:")
        patient_df.orderBy("timestamp", ascending=False).show(1, truncate=False, vertical=True)
    else:
        print(f"✗ No records found for patient in offline store")
        
except Exception as e:
    print(f"✗ Error querying offline store: {e}")

spark.stop()
EOF

echo "Querying offline store for date: $DATE"
echo ""

docker run --rm \
    --network clinical-mlops_mlops-network \
    -v /tmp/query_offline.py:/app/query.py \
    apache/spark:3.5.4-java17 \
    python /app/query.py

echo ""
echo "=========================================="
echo "Query Complete"
echo "=========================================="