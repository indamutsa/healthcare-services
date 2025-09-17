#!/bin/bash
# Infrastructure setup script for new projects

PROJECT_NAME=${1:-myproject}
CLOUD_PROVIDER=${2:-aws}

echo "🏗️  Setting up infrastructure for $PROJECT_NAME on $CLOUD_PROVIDER"

# Create directory structure
mkdir -p {infra/{environments/{dev,staging,prod},modules},k8s/{base,overlays/{dev,staging,prod}},security}

# Terraform structure
cat > infra/main.tf << EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    $CLOUD_PROVIDER = {
      source  = "hashicorp/$CLOUD_PROVIDER"
      version = "~> 5.0"
    }
  }
}

provider "$CLOUD_PROVIDER" {
  region = var.region
}

module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  environment  = var.environment
}

module "compute" {
  source = "./modules/compute"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids
}
EOF

cat > infra/variables.tf << EOF
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$PROJECT_NAME"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "Cloud provider region"
  type        = string
  default     = "us-west-2"
}
EOF

# Kubernetes base manifests
cat > k8s/base/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $PROJECT_NAME
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $PROJECT_NAME
  template:
    metadata:
      labels:
        app: $PROJECT_NAME
    spec:
      containers:
      - name: app
        image: $PROJECT_NAME:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
EOF

cat > k8s/base/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: $PROJECT_NAME
spec:
  selector:
    app: $PROJECT_NAME
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
EOF

# ArgoCD Application
cat > k8s/argocd-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $PROJECT_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/$PROJECT_NAME
    targetRevision: HEAD
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: $PROJECT_NAME
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Security policies
cat > security/network-policy.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $PROJECT_NAME-netpol
spec:
  podSelector:
    matchLabels:
      app: $PROJECT_NAME
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - {}
EOF

echo "✅ Infrastructure structure created!"
echo "📁 Directories:"
echo "   - infra/ (Terraform)"
echo "   - k8s/ (Kubernetes manifests)"
echo "   - security/ (Security policies)"
echo ""
echo "🔧 Next steps:"
echo "   1. Update Terraform variables in infra/environments/"
echo "   2. Customize Kubernetes manifests"
echo "   3. Configure ArgoCD repository"
echo "   4. Apply security policies"