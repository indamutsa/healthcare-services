#!/bin/bash

set -e

# Configuration
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-west-2
AWS_ENDPOINT_URL=http://localhost:4566

# Export environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION
export AWS_ENDPOINT_URL

echo "🚀 Setting up LocalStack services for Clinical MLOps Platform..."

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
until aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL; do
  echo "Waiting for LocalStack..."
  sleep 2
done
echo "✅ LocalStack is ready!"

# Create S3 buckets
echo "🪣 Creating S3 buckets..."
aws s3 mb s3://clinical-mlops-artifacts --endpoint-url=$AWS_ENDPOINT_URL || echo "Bucket already exists"
aws s3 mb s3://clinical-mlops-mlflow --endpoint-url=$AWS_ENDPOINT_URL || echo "Bucket already exists"
aws s3 mb s3://clinical-mlops-datasets --endpoint-url=$AWS_ENDPOINT_URL || echo "Bucket already exists"
aws s3 mb s3://clinical-mlops-models --endpoint-url=$AWS_ENDPOINT_URL || echo "Bucket already exists"

# Create SQS queues
echo "📮 Creating SQS queues..."
aws sqs create-queue --queue-name clinical-data-ingestion --endpoint-url=$AWS_ENDPOINT_URL || echo "Queue already exists"
aws sqs create-queue --queue-name feature-engineering --endpoint-url=$AWS_ENDPOINT_URL || echo "Queue already exists"
aws sqs create-queue --queue-name model-training --endpoint-url=$AWS_ENDPOINT_URL || echo "Queue already exists"
aws sqs create-queue --queue-name model-serving --endpoint-url=$AWS_ENDPOINT_URL || echo "Queue already exists"

# Create SNS topics
echo "📢 Creating SNS topics..."
aws sns create-topic --name clinical-data-updates --endpoint-url=$AWS_ENDPOINT_URL || echo "Topic already exists"
aws sns create-topic --name model-updates --endpoint-url=$AWS_ENDPOINT_URL || echo "Topic already exists"
aws sns create-topic --name monitoring-alerts --endpoint-url=$AWS_ENDPOINT_URL || echo "Topic already exists"

# Subscribe SQS queues to SNS topics
CLINICAL_DATA_QUEUE_URL=$(aws sqs get-queue-url --queue-name clinical-data-ingestion --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrl' --output text)
MODEL_UPDATES_QUEUE_URL=$(aws sqs get-queue-url --queue-name model-training --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrl' --output text)

echo "🔗 Subscribing queues to topics..."
aws sns subscribe --topic-arn arn:aws:sns:us-west-2:123456789012:clinical-data-updates --protocol sqs --notification-endpoint $CLINICAL_DATA_QUEUE_URL --endpoint-url=$AWS_ENDPOINT_URL || echo "Subscription already exists"
aws sns subscribe --topic-arn arn:aws:sns:us-west-2:123456789012:model-updates --protocol sqs --notification-endpoint $MODEL_UPDATES_QUEUE_URL --endpoint-url=$AWS_ENDPOINT_URL || echo "Subscription already exists"

# Create Secrets Manager secrets
echo "🔐 Creating Secrets Manager secrets..."
aws secretsmanager create-secret --name clinical-mlops-db-password --secret-string "postgres123" --endpoint-url=$AWS_ENDPOINT_URL || echo "Secret already exists"
aws secretsmanager create-secret --name clinical-mlops-redis-password --secret-string "redis123" --endpoint-url=$AWS_ENDPOINT_URL || echo "Secret already exists"
aws secretsmanager create-secret --name clinical-mlops-api-key --secret-string "clinical-mlops-api-key-$(date +%s)" --endpoint-url=$AWS_ENDPOINT_URL || echo "Secret already exists"

# Create IAM roles and policies (simulated)
echo "👤 Creating IAM roles..."
aws iam create-role --role-name ClinicalMLOpsServiceRole --assume-role-policy-document file:///dev/stdin <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF 2>/dev/null || echo "Role already exists"

aws iam put-role-policy --role-name ClinicalMLOpsServiceRole --policy-name ClinicalMLOpsAccess --policy-document file:///dev/stdin <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "sqs:*",
        "sns:*",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create sample data in S3
echo "📊 Creating sample datasets..."
echo '{"patient_id": "P001", "age": 45, "gender": "F", "condition": "diabetes", "treatment": "metformin"}' > /tmp/sample-patient.json
aws s3 cp /tmp/sample-patient.json s3://clinical-mlops-datasets/sample-patient.json --endpoint-url=$AWS_ENDPOINT_URL

echo '{"model_name": "diabetes-predictor", "version": "1.0", "accuracy": 0.85, "auc": 0.88}' > /tmp/sample-model.json
aws s3 cp /tmp/sample-model.json s3://clinical-mlops-models/sample-model.json --endpoint-url=$AWS_ENDPOINT_URL

# Send test messages to SQS
echo "📨 Sending test messages to SQS..."
aws sqs send-message --queue-url $CLINICAL_DATA_QUEUE_URL --message-body '{"event_type": "new_patient", "patient_id": "P001"}' --endpoint-url=$AWS_ENDPOINT_URL
aws sqs send-message --queue-url $MODEL_UPDATES_QUEUE_URL --message-body '{"event_type": "model_update", "model_name": "diabetes-predictor", "version": "1.0"}' --endpoint-url=$AWS_ENDPOINT_URL

# Publish test messages to SNS
echo "📢 Publishing test messages to SNS..."
aws sns publish --topic-arn arn:aws:sns:us-west-2:123456789012:clinical-data-updates --message '{"event_type": "batch_complete", "records_processed": 1000}' --endpoint-url=$AWS_ENDPOINT_URL
aws sns publish --topic-arn arn:aws:sns:us-west-2:123456789012:model-updates --message '{"event_type": "model_deployed", "model_name": "diabetes-predictor", "version": "1.0"}' --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ LocalStack setup completed successfully!"
echo ""
echo "📋 Summary of created resources:"
echo "S3 Buckets:"
aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL
echo ""
echo "SQS Queues:"
aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL
echo ""
echo "SNS Topics:"
aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL
echo ""
echo "Secrets Manager:"
aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretList[*].Name' --output table
echo ""
echo "🎉 LocalStack is now ready for development and testing!"