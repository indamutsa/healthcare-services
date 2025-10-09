```sh                                                                                                    
docker run --rm \      
  --network clinical-trials-service_mlops-network \
  -e KAFKA_BOOTSTRAP_SERVERS=kafka:29092 \
  -e NUM_PATIENTS=100 \
  -e PRODUCER_RATE=10 \
  kafka-producer
```

```sh
docker compose up -d kafka zookeeper kafka-ui minio minio-setup kafka-producer kafka-consumer spark-master spark-batch spark-streaming spark-worker 
```