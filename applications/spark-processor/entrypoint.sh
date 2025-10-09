#!/bin/bash
set -e

INTERVAL_MINUTES=${INTERVAL_MINUTES:-60}
SPARK_CMD=("$@")  # Capture CMD arguments, if any

echo "============================================================"
echo "Continuous Spark Batch Processor"
echo "Interval: ${INTERVAL_MINUTES} minutes"
echo "============================================================"

while true; do
  echo ""
  echo "⏰ Starting batch job at $(date)"
  echo "============================================================"

  if [ ${#SPARK_CMD[@]} -eq 0 ]; then
    # Default behavior
    /opt/spark/bin/spark-submit \
      --master spark://spark-master:7077 \
      --deploy-mode client \
      --packages org.apache.hadoop:hadoop-aws:3.3.4 \
      --conf spark.executor.memory=2g \
      --conf spark.executor.cores=2 \
      --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
      --conf spark.hadoop.fs.s3a.access.key=minioadmin \
      --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
      --conf spark.hadoop.fs.s3a.path.style.access=true \
      --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
      --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
      /opt/spark/work-dir/jobs/bronze_to_silver_batch.py
  else
    echo "Running custom Spark command: ${SPARK_CMD[*]}"
    "${SPARK_CMD[@]}"
  fi

  echo "✅ Batch completed at $(date)"
  echo "Sleeping ${INTERVAL_MINUTES} minutes before next run..."
  sleep $((INTERVAL_MINUTES * 60))
done
