```sh
docker compose up -d kafka zookeeper kafka-ui
                                                                                                           0.0s 
docker run --rm \                                   ✔  ⚡  35  15:56:05 
  --network clinical-trials-service_mlops-network \
  -e KAFKA_BOOTSTRAP_SERVERS=kafka:29092 \
  -e NUM_PATIENTS=100 \
  -e PRODUCER_RATE=10 \
  kafka-producer
```

```sh
docker compose up -d kafka zookeeper kafka-ui minio minio-setup
```