# LocalStack Integration Guide

## Overview

The Clinical MLOps Platform uses a **hybrid AWS approach**:

- **MinIO**: S3-compatible object storage (production-ready)
- **LocalStack**: Other AWS services emulation (development/testing)

This provides the best of both worlds:
- ✅ Production-ready S3 (MinIO)
- ✅ Full AWS ecosystem for development (LocalStack)
- ✅ Easy cloud migration path
- ✅ Cost-effective local development

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              CLINICAL MLOPS PLATFORM                        │
│              Hybrid AWS Services                            │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────────┐
│   MinIO              │         │   LocalStack             │
│   (S3 Storage)       │         │   (Other AWS Services)   │
├──────────────────────┤         ├──────────────────────────┤
│                      │         │                          │
│ 🪣 S3 Buckets        │         │ 📨 SQS                   │
│  - mlflow-artifacts  │         │  - Event queues          │
│  - model-artifacts   │         │  - Processing queues     │
│  - feature-store     │         │                          │
│  - airflow-logs      │         │ 📢 SNS                   │
│  - backups           │         │  - Notifications         │
│                      │         │  - Alerts                │
│ Production Ready     │         │                          │
│ High Performance     │         │ 🗄️ DynamoDB              │
│ Same API as AWS S3   │         │  - Model metadata        │
│                      │         │  - Feature registry      │
│ Port: 9000           │         │  - Prediction cache      │
└──────────────────────┘         │                          │
                                 │ 🔐 Secrets Manager       │
                                 │  - API keys              │
                                 │  - Credentials           │
                                 │                          │
                                 │ 📊 CloudWatch            │
                                 │  - Logs                  │
                                 │  - Metrics               │
                                 │                          │
                                 │ 🌊 Kinesis               │
                                 │  - Event streams         │
                                 │                          │
                                 │ ⚡ Lambda (planned)       │
                                 │ 📅 EventBridge           │
                                 │ ⚙️ SSM Parameter Store   │
                                 │                          │
                                 │ Port: 4566               │
                                 └──────────────────────────┘
```

---

## Services Overview

### Enabled in LocalStack

| Service | Purpose | Example Use Case |
|---------|---------|------------------|
| **SQS** | Message queues | Event processing, async tasks |
| **SNS** | Pub/sub notifications | Model alerts, system notifications |
| **DynamoDB** | NoSQL database | Model metadata, feature registry |
| **Secrets Manager** | Secret storage | API keys, credentials |
| **CloudWatch Logs** | Log aggregation | Application logs, audit trails |
| **Kinesis** | Stream processing | Real-time event streams |
| **EventBridge** | Event bus | Scheduled tasks, event routing |
| **Lambda** | Serverless functions | Event processors (planned) |
| **SSM** | Parameter store | Configuration management |
| **IAM/STS** | Access management | Role-based access |
| **KMS** | Encryption keys | Data encryption |
| **ECR** | Container registry | Docker images (local) |

### Delegated to MinIO

| Service | MinIO Equivalent | Why MinIO |
|---------|------------------|-----------|
| **S3** | MinIO object storage | Production-ready, high performance |

---

## Quick Start

### 1. Start LocalStack (Docker Compose)

```bash
cd gitops-deployment/localstack
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f localstack
```

### 2. Start LocalStack (Kubernetes)

```bash
# Deploy LocalStack
kubectl apply -f kubernetes-manifests/infrastructure/localstack.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app=localstack -n clinical-mlops --timeout=300s

# Check logs
kubectl logs -f deployment/localstack -n clinical-mlops

# Port forward for local access
kubectl port-forward -n clinical-mlops svc/localstack 4566:4566
```

### 3. Initialize Resources

```bash
# Run init script (creates queues, topics, tables, etc.)
cd localstack
bash init-scripts/01-create-resources.sh
```

### 4. Verify Resources

```bash
# Set environment
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# List SQS queues
aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL

# List DynamoDB tables
aws dynamodb list-tables --endpoint-url=$AWS_ENDPOINT_URL

# List secrets
aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL
```

---

## Integration Examples

### Example 1: Send Message to SQS

```python
import boto3

# Configure for LocalStack
sqs = boto3.client(
    'sqs',
    endpoint_url='http://localstack:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

# Send message
queue_url = 'http://localstack:4566/000000000000/clinical-events-queue'
response = sqs.send_message(
    QueueUrl=queue_url,
    MessageBody='{"patient_id": "12345", "event": "new_visit"}'
)

print(f"Message ID: {response['MessageId']}")
```

### Example 2: Store Model Metadata in DynamoDB

```python
import boto3
from datetime import datetime

# Configure for LocalStack
dynamodb = boto3.resource(
    'dynamodb',
    endpoint_url='http://localstack:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

table = dynamodb.Table('model-metadata')

# Store model info
table.put_item(
    Item={
        'model_id': 'clinical-risk-model',
        'version': 'v1.2.3',
        'timestamp': int(datetime.now().timestamp()),
        'accuracy': 0.95,
        's3_path': 's3://model-artifacts/production/v1.2.3/',  # MinIO
        'status': 'production'
    }
)

print("Model metadata stored!")
```

### Example 3: Retrieve Secret from Secrets Manager

```python
import boto3
import json

# Configure for LocalStack
secretsmanager = boto3.client(
    'secretsmanager',
    endpoint_url='http://localstack:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

# Get secret
response = secretsmanager.get_secret_value(
    SecretId='clinical-mlops/api-keys'
)

secret = json.loads(response['SecretString'])
api_key = secret['api_key']

print(f"API Key: {api_key}")
```

### Example 4: Publish to SNS Topic

```python
import boto3

# Configure for LocalStack
sns = boto3.client(
    'sns',
    endpoint_url='http://localstack:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

# Get topic ARN
topics = sns.list_topics()
topic_arn = [t['TopicArn'] for t in topics['Topics'] if 'model-alerts' in t['TopicArn']][0]

# Publish message
response = sns.publish(
    TopicArn=topic_arn,
    Subject='Model Drift Detected',
    Message='Model accuracy dropped below threshold: 0.85'
)

print(f"Message published: {response['MessageId']}")
```

### Example 5: Write to CloudWatch Logs

```python
import boto3
import time

# Configure for LocalStack
logs = boto3.client(
    'logs',
    endpoint_url='http://localstack:4566',
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

# Create log stream
log_group = '/clinical-mlops/application'
log_stream = f'prediction-service-{int(time.time())}'

logs.create_log_stream(
    logGroupName=log_group,
    logStreamName=log_stream
)

# Put log events
logs.put_log_events(
    logGroupName=log_group,
    logStreamName=log_stream,
    logEvents=[
        {
            'timestamp': int(time.time() * 1000),
            'message': 'Prediction request received for patient_id=12345'
        }
    ]
)

print("Logs written!")
```

---

## Environment Variables

### For LocalStack Services

```bash
# LocalStack endpoint
export AWS_ENDPOINT_URL=http://localstack:4566

# Or service-specific (Kubernetes)
export SQS_ENDPOINT=http://localstack.clinical-mlops.svc.cluster.local:4566
export SNS_ENDPOINT=http://localstack.clinical-mlops.svc.cluster.local:4566
export DYNAMODB_ENDPOINT=http://localstack.clinical-mlops.svc.cluster.local:4566
export SECRETSMANAGER_ENDPOINT=http://localstack.clinical-mlops.svc.cluster.local:4566
```

### For MinIO (S3)

```bash
# MinIO S3 endpoint
export S3_ENDPOINT=http://minio:9000
export AWS_S3_ENDPOINT=http://minio:9000

# Credentials
export AWS_ACCESS_KEY_ID=<from-secret>
export AWS_SECRET_ACCESS_KEY=<from-secret>
```

---

## Created Resources

### SQS Queues
```
- clinical-events-queue
- model-training-queue
- feature-processing-queue
- prediction-requests-queue
- deadletter-queue
```

### SNS Topics
```
- clinical-events
- model-training-notifications
- feature-processing-notifications
- system-alerts
- model-drift-alerts
```

### DynamoDB Tables
```
- model-metadata (model_id, version)
- feature-registry (feature_id, timestamp)
- prediction-cache (patient_id) with TTL
- experiment-tracking (experiment_id, run_id)
```

### Secrets
```
- clinical-mlops/api-keys
- clinical-mlops/database
- clinical-mlops/external-services
```

### CloudWatch Log Groups
```
- /aws/lambda/model-training
- /aws/lambda/feature-processing
- /aws/lambda/prediction-service
- /clinical-mlops/application
- /clinical-mlops/audit
```

### Kinesis Streams
```
- clinical-events-stream (2 shards)
- model-predictions-stream (1 shard)
- feature-updates-stream (1 shard)
```

---

## Testing Workflows

### Workflow 1: Event Processing Pipeline

```python
# 1. Application publishes event to SNS
sns.publish(
    TopicArn='arn:aws:sns:us-east-1:000000000000:clinical-events',
    Message='{"event": "new_patient_data"}'
)

# 2. SNS delivers to subscribed SQS queue
# (automatically configured)

# 3. Worker polls SQS queue
messages = sqs.receive_message(
    QueueUrl='http://localstack:4566/000000000000/clinical-events-queue'
)

# 4. Process and store in DynamoDB
for message in messages.get('Messages', []):
    # Process...
    dynamodb.put_item(...)

    # Delete message
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=message['ReceiptHandle']
    )
```

### Workflow 2: Model Training with Metadata Tracking

```python
# 1. Start training
model = train_model(data)

# 2. Save model to MinIO (S3)
s3 = boto3.client('s3', endpoint_url='http://minio:9000')
s3.upload_file('model.pkl', 'model-artifacts', 'v1.2.3/model.pkl')

# 3. Store metadata in DynamoDB
dynamodb.put_item(
    TableName='model-metadata',
    Item={
        'model_id': 'clinical-risk-model',
        'version': 'v1.2.3',
        's3_path': 's3://model-artifacts/v1.2.3/',
        'metrics': {'accuracy': 0.95, 'precision': 0.93}
    }
)

# 4. Publish notification
sns.publish(
    TopicArn='arn:aws:sns:us-east-1:000000000000:model-training-notifications',
    Message=f'Model v1.2.3 training complete'
)
```

---

## Cloud Migration Path

### Phase 1: Local Development (Current)
```
MinIO (S3) + LocalStack (other services)
```

### Phase 2: Hybrid Cloud
```
AWS S3 (real) + LocalStack (dev/test)
MinIO (staging only)
```

### Phase 3: Full AWS
```
Just change endpoints:
- LocalStack → AWS services
- MinIO → AWS S3

No code changes needed!
```

### Migration Example

```python
# Before (LocalStack/MinIO)
s3_endpoint = 'http://minio:9000'
sqs_endpoint = 'http://localstack:4566'

# After (AWS)
s3_endpoint = None  # Use default AWS S3
sqs_endpoint = None  # Use default AWS SQS

# Same code works!
```

---

## Monitoring

### LocalStack Health

```bash
# Check health endpoint
curl http://localhost:4566/_localstack/health

# Expected response:
{
  "services": {
    "sqs": "running",
    "sns": "running",
    "dynamodb": "running",
    "secretsmanager": "running",
    ...
  }
}
```

### Resource Counts

```bash
# SQS
aws sqs list-queues --endpoint-url=http://localhost:4566 | grep -c "http"

# DynamoDB
aws dynamodb list-tables --endpoint-url=http://localhost:4566 | grep -c "Table"

# Secrets
aws secretsmanager list-secrets --endpoint-url=http://localhost:4566 | grep -c "Name"
```

---

## Best Practices

### ✅ DO
- Use LocalStack for development and testing
- Use MinIO for S3 (production-ready)
- Keep LocalStack credentials simple (`test/test`)
- Use the same AWS SDK code for local and cloud
- Test cloud migrations locally first

### ❌ DON'T
- Use LocalStack S3 (use MinIO instead)
- Store production data in LocalStack
- Rely on LocalStack for production workloads
- Hardcode endpoints (use environment variables)

---

## Troubleshooting

### LocalStack not starting

```bash
# Check logs
docker-compose logs localstack

# Common issues:
# 1. Port 4566 already in use
lsof -i :4566 | grep LISTEN

# 2. Docker socket permission
ls -l /var/run/docker.sock

# 3. Insufficient memory
docker stats localstack
```

### Resources not created

```bash
# Re-run init script
bash init-scripts/01-create-resources.sh

# Or manually create
awslocal sqs create-queue --queue-name my-queue
```

### Connection refused

```bash
# Verify LocalStack is running
curl http://localhost:4566/_localstack/health

# Check network
kubectl get svc localstack -n clinical-mlops
```

---

## Summary

| Component | Service | Endpoint | Purpose |
|-----------|---------|----------|---------|
| **MinIO** | S3 | :9000 | Object storage (production) |
| **LocalStack** | SQS, SNS, etc. | :4566 | AWS services (dev/test) |

**Benefits**:
- ✅ Production-ready S3 (MinIO)
- ✅ Full AWS ecosystem (LocalStack)
- ✅ Easy cloud migration
- ✅ Cost-effective development
- ✅ Same code for local and cloud

**Perfect for cloud-native MLOps!** 🚀
