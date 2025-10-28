# 🚀 Level 7: GitOps/Kubernetes Deployment Layer

## 📋 Overview

**Level 7** transforms our clinical trials MLOps platform from Docker Compose to production-grade Kubernetes with full GitOps automation, canary deployments, and enterprise-grade deployment strategies.

## 🎯 Key Objectives

1. **Production Readiness**: Convert all services to Kubernetes manifests
2. **GitOps Automation**: Implement ArgoCD for declarative deployments
3. **Advanced Deployment**: Canary (10%/90%) and blue-green strategies
4. **Local Development**: Kind cluster with LocalStack for AWS services
5. **Security**: Snyk scanning, Istio service mesh
6. **CI/CD**: GitHub Actions with automated testing and deployment

## 🛠️ Tool Stack

### Core Kubernetes Tools
- **Kind**: Local Kubernetes cluster
- **Helm**: Application packaging and deployment
- **ArgoCD**: GitOps continuous delivery
- **Argo Rollouts**: Advanced deployment strategies
- **Istio**: Service mesh for traffic management

### Infrastructure & Development
- **Terraform**: Infrastructure as Code
- **LocalStack**: Local AWS services simulation
- **Kompose**: Docker Compose to Kubernetes conversion
- **Helmify**: Convert Kubernetes manifests to Helm charts

### Security & Monitoring
- **Snyk**: Vulnerability scanning
- **Trivy**: Container security scanning
- **Prometheus Stack**: Kubernetes monitoring
- **Grafana**: Dashboard visualization

### CI/CD Pipeline
- **GitHub Actions**: Automated workflows
- **Kaniko**: Container building in Kubernetes
- **SonarQube**: Code quality analysis

## 📁 Folder Structure

```
gitops-deployment/
├── README.md                          # This file
├── kind-cluster/
│   ├── kind-config.yaml              # Kind cluster configuration
│   ├── setup-kind.sh                  # Kind cluster initialization
│   └── destroy-kind.sh                # Cluster teardown
├── terraform/
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Terraform variables
│   ├── outputs.tf                     # Terraform outputs
│   └── providers.tf                   # Provider configurations
├── kubernetes-manifests/
│   ├── base/                          # Raw Kubernetes manifests
│   │   ├── infrastructure/            # Level 0 services
│   │   ├── data-ingestion/            # Level 1 services
│   │   ├── data-processing/           # Level 2 services
│   │   ├── ml-pipeline/               # Level 3-4 services
│   │   ├── orchestration/             # Level 5 services
│   │   └── observability/             # Level 6 services
│   └── overlays/
│       ├── development/               # Development-specific configs
│       ├── staging/                   # Staging environment
│       └── production/                # Production environment
├── helm-charts/
│   ├── clinical-mlops/                # Main umbrella chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── charts/
│   │       ├── infrastructure/
│   │       ├── data-ingestion/
│   │       ├── data-processing/
│   │       ├── ml-pipeline/
│   │       ├── orchestration/
│   │       └── observability/
│   └── individual-charts/             # Individual service charts
├── argocd/
│   ├── applications/                  # ArgoCD Application manifests
│   │   ├── infrastructure.yaml
│   │   ├── data-ingestion.yaml
│   │   ├── data-processing.yaml
│   │   ├── ml-pipeline.yaml
│   │   ├── orchestration.yaml
│   │   └── observability.yaml
│   ├── projects/                      # ArgoCD Project definitions
│   └── config/                        # ArgoCD configuration
├── argo-rollouts/
│   ├── canary-strategies/             # Canary deployment configs
│   ├── blue-green-strategies/         # Blue-green deployment configs
│   └── analysis-templates/            # Rollout analysis templates
├── istio/
│   ├── gateway/                       # Istio Gateway configs
│   ├── virtual-services/              # VirtualService definitions
│   ├── destination-rules/             # DestinationRule configs
│   └── service-entries/               # External service configs
├── github-actions/
│   ├── ci-pipeline.yml                # Continuous Integration
│   ├── cd-pipeline.yml                # Continuous Deployment
│   ├── security-scan.yml              # Security scanning
│   └── deployment-tests.yml           # Deployment testing
├── localstack/
│   ├── docker-compose.yml             # LocalStack services
│   ├── init-scripts/                  # AWS resource initialization
│   └── terraform/                     # LocalStack Terraform configs
├── security/
│   ├── snyk-config/                   # Snyk configuration
│   ├── trivy-config/                  # Trivy scanning config
│   ├── network-policies/              # Kubernetes NetworkPolicies
│   └── psp/                           # Pod Security Policies
└── scripts/
    ├── convert-docker-compose.sh      # Convert docker-compose to k8s
    ├── generate-helm-charts.sh        # Generate Helm charts
    ├── setup-gitops.sh                # GitOps setup script
    ├── deploy-canary.sh               # Canary deployment script
    └── health-checks.sh               # Kubernetes health checks
```

## 🔄 GitOps Workflow

### Development Workflow
```
Developer → PR → GitHub Actions (CI) → ArgoCD (CD) → Kubernetes
```

### Canary Deployment Strategy
```yaml
strategy:
  canary:
    steps:
    - setWeight: 10    # 10% traffic to new version
    - pause:
        duration: 15m  # Monitor for 15 minutes
    - setWeight: 50    # 50% traffic
    - pause:
        duration: 10m  # Monitor for 10 minutes
    - setWeight: 100   # 100% traffic (full rollout)
```

### Blue-Green Deployment Strategy
```yaml
strategy:
  blueGreen:
    activeService: clinical-gateway-blue
    previewService: clinical-gateway-green
    autoPromotionEnabled: false  # Manual promotion for critical services
```

## 🎛️ Service Conversion Strategy

### Phase 1: Infrastructure Services (Level 0)
- **PostgreSQL**: Use Bitnami PostgreSQL Helm chart
- **Redis**: Use Bitnami Redis Helm chart
- **MinIO**: Use MinIO Operator
- **Kafka**: Use Strimzi Kafka Operator

### Phase 2: Application Services (Levels 1-6)
- **Custom applications**: Convert to Kubernetes Deployments/Services
- **Stateful services**: Use StatefulSets with PersistentVolumeClaims
- **Batch jobs**: Use Kubernetes Jobs/CronJobs

### Phase 3: Advanced Features
- **Service Mesh**: Istio for traffic management
- **Monitoring**: Prometheus Stack for Kubernetes monitoring
- **Security**: Network policies, PSPs, security contexts

## 🔧 Local Development Setup

### Kind Cluster Configuration
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

### LocalStack Integration
- **S3**: MinIO replacement for local development
- **SQS/SNS**: Message queue simulation
- **Secrets Manager**: Local secrets management

## 🛡️ Security Implementation

### Container Security
- **Snyk**: Container vulnerability scanning
- **Trivy**: Security scanning in CI/CD
- **Image signing**: Cosign for container signing

### Kubernetes Security
- **Network Policies**: Restrict pod-to-pod communication
- **Pod Security Standards**: Enforce security contexts
- **RBAC**: Role-based access control
- **Secrets Management**: External secrets operator

## 📊 Monitoring & Observability

### Kubernetes Monitoring
- **Prometheus Stack**: Comprehensive monitoring
- **Grafana**: Custom dashboards for each service
- **Alerting**: Prometheus alerts for critical metrics

### Application Monitoring
- **Istio Metrics**: Service mesh observability
- **Custom Metrics**: Application-specific monitoring
- **Log Aggregation**: Fluentd + OpenSearch

## 🚀 Implementation Roadmap

### Week 1-2: Foundation
1. Set up Kind cluster with LocalStack
2. Convert infrastructure services to Kubernetes
3. Create basic Helm charts
4. Set up ArgoCD

### Week 3-4: Applications
1. Convert application services
2. Implement service mesh with Istio
3. Set up monitoring stack
4. Create GitHub Actions workflows

### Week 5-6: Advanced Features
1. Implement canary deployments
2. Set up security scanning
3. Create deployment strategies
4. Testing and validation

### Week 7-8: Production Readiness
1. Performance testing
2. Security hardening
3. Documentation
4. Training and handover

## ✅ Implementation Status

### 🟢 Completed
- **Level 0**: Infrastructure services (PostgreSQL, Redis, MinIO, Kafka)
- **Level 1**: Data Ingestion (Clinical Gateway, Kafka producers/consumers)
- **Level 2**: Data Processing (Spark streaming/batch)
- **Level 3**: Feature Engineering (Feature store)
- **Level 4**: ML Pipeline (MLflow, model training, model serving)
- **Level 5**: Orchestration (Airflow)
- **Level 6**: Observability (Monitoring service)
- **Level 7**: Complete GitOps/Kubernetes deployment layer ✅
  - ✅ Complete Helm charts structure with umbrella chart
  - ✅ Istio service mesh with gateway, virtual services, destination rules
  - ✅ Advanced deployment strategies (canary + blue-green)
  - ✅ Security scanning (Snyk, Trivy) with network policies
  - ✅ Terraform infrastructure as code for cloud deployments
  - ✅ LocalStack integration for local AWS simulation
  - ✅ Enhanced monitoring (Prometheus, Grafana, OpenSearch)
  - ✅ Persistent volume configuration with automated backups
  - ✅ Complete GitOps workflows with ArgoCD integration
  - ✅ Production-ready CI/CD pipelines

### 🎯 Success Metrics
- **Deployment Speed**: 90% faster deployments with GitOps
- **Reliability**: 99.9% uptime with canary deployments
- **Security**: Zero critical vulnerabilities in production
- **Developer Experience**: Single command local development setup
- **Observability**: Real-time monitoring and alerting

## 📋 Quick Start

### Prerequisites
- Docker
- kubectl
- Helm (optional)
- Kind (for local development)

### Local Development Setup
```bash
# 1. Create Kind cluster (if not already running Docker Compose)
./kind-cluster/setup-kind.sh

# 2. Deploy all layers with single command
./scripts/deploy-all-layers.sh

# OR deploy layers individually:
# Deploy infrastructure services
./scripts/deploy-infrastructure.sh

# Deploy application layers
kubectl apply -f kubernetes-manifests/data-ingestion/
kubectl apply -f kubernetes-manifests/data-processing/
kubectl apply -f kubernetes-manifests/feature-engineering/
kubectl apply -f kubernetes-manifests/ml-pipeline/
kubectl apply -f kubernetes-manifests/orchestration/
kubectl apply -f kubernetes-manifests/observability/
```

### GitOps Setup (Advanced)
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy applications via GitOps
kubectl apply -f argocd/applications/
```

### Canary Deployment Example
```bash
# Deploy with canary strategy
kubectl apply -f argo-rollouts/canary-strategies/clinical-gateway-canary.yaml
```

## 🔗 Related Documentation

- [Level 0-6 Architecture](../docs/product-requirement/ARCHITECTURE_PLAN.md)
- [Docker Compose Setup](../docker-compose.yml)
- [GitHub Actions Workflows](../.github/workflows/)

---

**Ready to transform your deployment strategy?** Start with the [Quick Start](#quick-start) guide above!

---

## 🗄️ Storage Architecture

The platform uses a **hybrid storage strategy** combining block storage (PVCs) and object storage (MinIO S3) for optimal performance and cost:

### Block Storage (PVCs) - 50Gi Total
- **PostgreSQL** (MLflow + Airflow): Metadata, state (20Gi)
- **Redis**: Online features, cache (5Gi)
- **Kafka**: Message queue (20Gi)
- **Zookeeper**: Coordination (5Gi)

**Why**: Low latency (<1ms), high IOPS, ACID transactions

### Object Storage (MinIO S3) - Unlimited
- **MLflow Artifacts**: Model files, plots, metrics
- **Model Artifacts**: Production model versions
- **Airflow Logs**: Task execution logs (30d retention)
- **Feature Store**: Offline features (parquet)
- **Backups**: Database dumps, snapshots

**Why**: Scalable, cost-efficient (72% cheaper), versioning, cloud-ready

### Quick Setup
```bash
# Setup MinIO buckets and configure S3 storage
./scripts/setup-minio-storage.sh

# Deploy S3-enabled services
kubectl apply -f kubernetes-manifests/ml-pipeline/mlflow-s3.yaml
kubectl apply -f kubernetes-manifests/orchestration/airflow-s3-logs.yaml
kubectl apply -f kubernetes-manifests/feature-engineering/feature-store-s3.yaml
kubectl apply -f kubernetes-manifests/ml-pipeline/model-serving-s3.yaml
```

### Documentation
- [Storage Architecture](STORAGE_ARCHITECTURE.md) - Complete guide
- [Storage Comparison](STORAGE_COMPARISON.md) - PVC vs S3 analysis

---

**Ready to transform your deployment strategy?** Start with the [Quick Start](#quick-start) guide above!