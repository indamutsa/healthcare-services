#!/bin/bash
# Continuous pipeline monitoring

watch -n 5 -c "
echo '🔄 Refreshing every 5 seconds...'
echo ''
echo '📊 Message Counts (last 5 seconds):'
timeout 2 docker exec kafka kafka-console-consumer \\
  --bootstrap-server localhost:9092 \\
  --topic patient-vitals \\
  --from-beginning \\
  --max-messages 5 2>/dev/null | wc -l | xargs echo '  Vitals:'
echo ''
echo '💾 MinIO Bronze Files:'
docker run --rm --network clinical-trials-service_mlops-network \\
  --entrypoint /bin/sh \\
  minio/mc:latest \\
  -c 'mc alias set m http://minio:9000 minioadmin minioadmin 2>/dev/null && \\
      mc ls --recursive m/clinical-mlops/raw/ 2>/dev/null | wc -l' | xargs echo '  Total:'
echo ''
echo '✨ MinIO Silver Files:'
docker run --rm --network clinical-trials-service_mlops-network \\
  --entrypoint /bin/sh \\
  minio/mc:latest \\
  -c 'mc alias set m http://minio:9000 minioadmin minioadmin 2>/dev/null && \\
      mc ls --recursive m/clinical-mlops/processed/ 2>/dev/null | wc -l' | xargs echo '  Total:'
"