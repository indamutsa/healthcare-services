terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = []
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Configure AWS provider for LocalStack
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-west-2"
  s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  endpoints {
    s3        = "http://localhost:4566"
    sqs       = "http://localhost:4566"
    sns       = "http://localhost:4566"
    lambda    = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    iam       = "http://localhost:4566"
    sts       = "http://localhost:4566"
  }
}

# S3 Buckets for ML Artifacts
resource "aws_s3_bucket" "ml_artifacts" {
  bucket = "clinical-mlops-artifacts"
  force_destroy = true
}

resource "aws_s3_bucket" "mlflow_tracking" {
  bucket = "clinical-mlops-mlflow"
  force_destroy = true
}

resource "aws_s3_bucket" "datasets" {
  bucket = "clinical-mlops-datasets"
  force_destroy = true
}

resource "aws_s3_bucket" "models" {
  bucket = "clinical-mlops-models"
  force_destroy = true
}

# SQS Queues
resource "aws_sqs_queue" "clinical_data_ingestion" {
  name = "clinical-data-ingestion"
  
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300       # 5 minutes
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_sqs_queue" "feature_engineering" {
  name = "feature-engineering"
  
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 300
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_sqs_queue" "model_training" {
  name = "model-training"
  
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 600  # 10 minutes for training jobs
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_sqs_queue" "model_serving" {
  name = "model-serving"
  
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 60   # 1 minute for inference
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

# SNS Topics
resource "aws_sns_topic" "clinical_data_updates" {
  name = "clinical-data-updates"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_sns_topic" "model_updates" {
  name = "model-updates"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_sns_topic" "monitoring_alerts" {
  name = "monitoring-alerts"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

# SNS to SQS Subscriptions
resource "aws_sns_topic_subscription" "clinical_data_to_ingestion" {
  topic_arn = aws_sns_topic.clinical_data_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.clinical_data_ingestion.arn
}

resource "aws_sns_topic_subscription" "model_updates_to_training" {
  topic_arn = aws_sns_topic.model_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.model_training.arn
}

# Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "clinical-mlops-db-password"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = "postgres123"
}

resource "aws_secretsmanager_secret" "redis_password" {
  name = "clinical-mlops-redis-password"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_secretsmanager_secret_version" "redis_password" {
  secret_id = aws_secretsmanager_secret.redis_password.id
  secret_string = "redis123"
}

resource "aws_secretsmanager_secret" "api_key" {
  name = "clinical-mlops-api-key"
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
  secret_string = "clinical-mlops-api-key-${random_string.api_key.result}"
}

# IAM Role for Services
resource "aws_iam_role" "service_role" {
  name = "ClinicalMLOpsServiceRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Environment = "local"
    Project     = "clinical-mlops"
  }
}

resource "aws_iam_role_policy" "service_policy" {
  name = "ClinicalMLOpsAccess"
  role = aws_iam_role.service_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "sqs:*",
          "sns:*",
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Local resource for initialization script
resource "local_file" "init_script" {
  content = templatefile("${path.module}/../init-scripts/setup-services.sh", {
    aws_access_key_id = "test"
    aws_secret_access_key = "test"
    aws_default_region = "us-west-2"
    aws_endpoint_url = "http://localhost:4566"
  })
  filename = "${path.module}/init-generated.sh"
}

# Random string for API key generation
resource "random_string" "api_key" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Null resource to trigger initialization
resource "null_resource" "localstack_init" {
  depends_on = [
    aws_s3_bucket.ml_artifacts,
    aws_s3_bucket.mlflow_tracking,
    aws_s3_bucket.datasets,
    aws_s3_bucket.models,
    aws_sqs_queue.clinical_data_ingestion,
    aws_sqs_queue.feature_engineering,
    aws_sqs_queue.model_training,
    aws_sqs_queue.model_serving,
    aws_sns_topic.clinical_data_updates,
    aws_sns_topic.model_updates,
    aws_sns_topic.monitoring_alerts,
    aws_secretsmanager_secret.db_password,
    aws_secretsmanager_secret.redis_password,
    aws_secretsmanager_secret.api_key
  ]
  
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "chmod +x ${path.module}/../init-scripts/setup-services.sh && ${path.module}/../init-scripts/setup-services.sh"
  }
}