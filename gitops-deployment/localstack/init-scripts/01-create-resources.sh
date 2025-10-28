#!/bin/bash

# LocalStack Initialization Script
# Creates AWS resources on LocalStack startup
# NOTE: S3 is handled by MinIO (same API)

set -e

echo "🚀 Initializing LocalStack AWS Resources..."
echo "Note: S3 buckets are managed by MinIO"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
awslocal --version
sleep 5

# ========================================
# SQS Queues
# ========================================
echo "📨 Creating SQS Queues..."

awslocal sqs create-queue --queue-name clinical-events-queue
awslocal sqs create-queue --queue-name model-training-queue
awslocal sqs create-queue --queue-name feature-processing-queue
awslocal sqs create-queue --queue-name prediction-requests-queue
awslocal sqs create-queue --queue-name deadletter-queue

# Set queue attributes
awslocal sqs set-queue-attributes \
  --queue-url http://localhost:4566/000000000000/clinical-events-queue \
  --attributes VisibilityTimeout=300,MessageRetentionPeriod=1209600

echo "✅ SQS Queues created"

# ========================================
# SNS Topics
# ========================================
echo "📢 Creating SNS Topics..."

awslocal sns create-topic --name clinical-events
awslocal sns create-topic --name model-training-notifications
awslocal sns create-topic --name feature-processing-notifications
awslocal sns create-topic --name system-alerts
awslocal sns create-topic --name model-drift-alerts

# Subscribe SQS to SNS
TOPIC_ARN=$(awslocal sns list-topics --query "Topics[?contains(TopicArn, 'clinical-events')].TopicArn" --output text)
QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/clinical-events-queue --attribute-names QueueArn --query "Attributes.QueueArn" --output text)

awslocal sns subscribe --topic-arn $TOPIC_ARN --protocol sqs --notification-endpoint $QUEUE_ARN

echo "✅ SNS Topics created and subscribed"

# ========================================
# DynamoDB Tables
# ========================================
echo "🗄️ Creating DynamoDB Tables..."

# Model Metadata Table
awslocal dynamodb create-table \
  --table-name model-metadata \
  --attribute-definitions \
    AttributeName=model_id,AttributeType=S \
    AttributeName=version,AttributeType=S \
  --key-schema \
    AttributeName=model_id,KeyType=HASH \
    AttributeName=version,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

# Feature Registry Table
awslocal dynamodb create-table \
  --table-name feature-registry \
  --attribute-definitions \
    AttributeName=feature_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=feature_id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

# Prediction Cache Table
awslocal dynamodb create-table \
  --table-name prediction-cache \
  --attribute-definitions \
    AttributeName=patient_id,AttributeType=S \
  --key-schema \
    AttributeName=patient_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --time-to-live-specification "Enabled=true,AttributeName=ttl"

# Experiment Tracking Table
awslocal dynamodb create-table \
  --table-name experiment-tracking \
  --attribute-definitions \
    AttributeName=experiment_id,AttributeType=S \
    AttributeName=run_id,AttributeType=S \
  --key-schema \
    AttributeName=experiment_id,KeyType=HASH \
    AttributeName=run_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

echo "✅ DynamoDB Tables created"

# ========================================
# Secrets Manager
# ========================================
echo "🔐 Creating Secrets..."

awslocal secretsmanager create-secret \
  --name clinical-mlops/api-keys \
  --secret-string '{
    "api_key": "test-api-key-12345",
    "service_key": "test-service-key-67890",
    "webhook_secret": "test-webhook-secret"
  }'

awslocal secretsmanager create-secret \
  --name clinical-mlops/database \
  --secret-string '{
    "host": "postgres-mlflow",
    "port": "5432",
    "username": "mlflow_user",
    "password": "test-password",
    "database": "mlflow_db"
  }'

awslocal secretsmanager create-secret \
  --name clinical-mlops/external-services \
  --secret-string '{
    "slack_webhook": "https://hooks.slack.com/test",
    "pagerduty_key": "test-pd-key"
  }'

echo "✅ Secrets created"

# ========================================
# CloudWatch Log Groups
# ========================================
echo "📊 Creating CloudWatch Log Groups..."

awslocal logs create-log-group --log-group-name /aws/lambda/model-training
awslocal logs create-log-group --log-group-name /aws/lambda/feature-processing
awslocal logs create-log-group --log-group-name /aws/lambda/prediction-service
awslocal logs create-log-group --log-group-name /clinical-mlops/application
awslocal logs create-log-group --log-group-name /clinical-mlops/audit

echo "✅ CloudWatch Log Groups created"

# ========================================
# Kinesis Streams
# ========================================
echo "🌊 Creating Kinesis Streams..."

awslocal kinesis create-stream \
  --stream-name clinical-events-stream \
  --shard-count 2

awslocal kinesis create-stream \
  --stream-name model-predictions-stream \
  --shard-count 1

awslocal kinesis create-stream \
  --stream-name feature-updates-stream \
  --shard-count 1

echo "✅ Kinesis Streams created"

# ========================================
# EventBridge Rules
# ========================================
echo "📅 Creating EventBridge Rules..."

awslocal events put-rule \
  --name model-retraining-schedule \
  --schedule-expression "rate(7 days)" \
  --state ENABLED

awslocal events put-rule \
  --name feature-refresh-schedule \
  --schedule-expression "rate(1 hour)" \
  --state ENABLED

echo "✅ EventBridge Rules created"

# ========================================
# SSM Parameters
# ========================================
echo "⚙️ Creating SSM Parameters..."

awslocal ssm put-parameter \
  --name /clinical-mlops/config/model-version \
  --value "v1.0.0" \
  --type String

awslocal ssm put-parameter \
  --name /clinical-mlops/config/feature-store-path \
  --value "s3://feature-store/offline/" \
  --type String

awslocal ssm put-parameter \
  --name /clinical-mlops/config/enable-monitoring \
  --value "true" \
  --type String

echo "✅ SSM Parameters created"

# ========================================
# Summary
# ========================================
echo ""
echo "🎉 LocalStack initialization complete!"
echo ""
echo "📊 Summary of created resources:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SQS Queues:"
awslocal sqs list-queues
echo ""
echo "SNS Topics:"
awslocal sns list-topics
echo ""
echo "DynamoDB Tables:"
awslocal dynamodb list-tables
echo ""
echo "Secrets:"
awslocal secretsmanager list-secrets --query "SecretList[*].Name"
echo ""
echo "CloudWatch Log Groups:"
awslocal logs describe-log-groups --query "logGroups[*].logGroupName"
echo ""
echo "Kinesis Streams:"
awslocal kinesis list-streams
echo ""
echo "EventBridge Rules:"
awslocal events list-rules --query "Rules[*].Name"
echo ""
echo "SSM Parameters:"
awslocal ssm describe-parameters --query "Parameters[*].Name"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All AWS services ready (S3 → MinIO)"
