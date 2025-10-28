terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = []
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
      configuration_aliases = []
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
      configuration_aliases = []
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
      configuration_aliases = []
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
      configuration_aliases = []
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "clinical-mlops"
      ManagedBy   = "terraform"
      CreatedAt   = timestamp()
    }
  }
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  config_path = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

# Helm Provider Configuration  
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

# Random Provider Configuration
provider "random" {}