# Level 7: GitOps/Kubernetes Deployment Guide

## Overview

This guide covers the GitOps/Kubernetes deployment layer for the Clinical Trials MLOps Platform. The platform is organized into 7 levels, with Level 7 providing production-grade deployment capabilities.

## Architecture

### Level 7 Components

- **GitOps Workflow**: ArgoCD + GitHub Actions
- **Kubernetes Cluster**: Local (Kind) or Cloud (EKS/GKE/AKS)
- **Deployment Strategies**: Canary (10%/90%) and Blue-Green
- **Service Mesh**: Istio for traffic management
- **Security**: Snyk + Trivy scanning
- **Monitoring**: Prometheus + Grafana + OpenSearch

### Application Layers

1. **Level 0**: Infrastructure (PostgreSQL, Redis, MinIO, Kafka)
2. **Level 1**: Data Ingestion (Kafka producers/consumers, MQ)
3. **Level 2**: Data Processing (Spark streaming/batch)
4. **Level 3**: Feature Engineering
5. **Level 4**: ML Pipeline (MLflow, training, serving)
6. **Level 5**: Orchestration (Airflow)
7. **Level 6**: Observability (Monitoring, logging)

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Kubernetes cluster (Kind, Minikube, or cloud)
- kubectl
- Helm (optional)

### 1. Local Development with Kind

```bash
cd gitops-deployment/kind-cluster
./setup-kind.sh
```

### 2. Deploy Infrastructure (Level 0)

```bash
cd gitops-deployment/scripts
./deploy-infrastructure.sh
```

### 3. Deploy Application Layers

```bash
# Deploy all layers
kubectl apply -f kubernetes-manifests/data-ingestion/
kubectl apply -f kubernetes-manifests/data-processing/
kubectl apply -f kubernetes-manifests/features/
kubectl apply -f kubernetes-manifests/ml-pipeline/
kubectl apply -f kubernetes-manifests/orchestration/
kubectl apply -f kubernetes-manifests/observability/
```

## Kubernetes Manifests Structure

```
gitops-deployment/kubernetes-manifests/
├── infrastructure/          # Level 0
│   ├── postgres-mlflow.yaml
│   ├── redis.yaml
│   ├── minio.yaml
│   ├── kafka.yaml
│   ├── Chart.yaml
│   └── values.yaml
├── data-ingestion/         # Level 1
├── data-processing/        # Level 2
├── features/               # Level 3
├── ml-pipeline/            # Level 4
├── orchestration/          # Level 5
└── observability/          # Level 6
```

## GitOps Workflow

### ArgoCD Setup

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Application Definitions

See `argocd/applications/infrastructure.yaml` for example ArgoCD application definitions.

## Deployment Strategies

### Canary Deployment (10%/90%)

```yaml
# See argo-rollouts/canary-strategies/clinical-gateway-canary.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 90
      - pause: {duration: 10m}
```

### Blue-Green Deployment

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: clinical-gateway-active
      previewService: clinical-gateway-preview
      autoPromotionEnabled: false
```

## CI/CD Pipeline

### GitHub Actions

See `github-actions/ci-pipeline.yml` for the complete CI/CD workflow:

1. **Build**: Docker image builds
2. **Test**: Unit and integration tests
3. **Scan**: Security scanning with Snyk and Trivy
4. **Deploy**: GitOps deployment via ArgoCD

### Manual Deployment

For development and testing:

```bash
# Build and push images
./scripts/build-images.sh

# Deploy to Kubernetes
./scripts/deploy-all.sh

# Run tests
./scripts/run-tests.sh
```

## Monitoring and Observability

### Access Services

- **Grafana**: http://localhost:30300 (admin/admin)
- **Prometheus**: http://localhost:30900
- **OpenSearch Dashboards**: http://localhost:30560
- **Kafka UI**: http://localhost:9800
- **MinIO Console**: http://localhost:9801

### Health Checks

```bash
# Check all deployments
kubectl get pods --all-namespaces

# Check specific service health
kubectl get services

# View logs
kubectl logs -f deployment/clinical-gateway
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Use higher ports in Kind configuration
2. **Resource Limits**: Adjust CPU/memory in deployment manifests
3. **Storage**: Ensure PVCs are bound and storage class is available

### Debug Commands

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes

# Check pod status
kubectl get pods --all-namespaces

# View events
kubectl get events --all-namespaces

# Check resource usage
kubectl top pods --all-namespaces
```

## Production Considerations

### Security

- Use sealed secrets for sensitive data
- Implement network policies
- Enable RBAC and service accounts
- Regular security scanning

### Scaling

- Horizontal Pod Autoscaling (HPA)
- Cluster Autoscaling
- Resource limits and requests

### Backup and Recovery

- Database backups
- Volume snapshots
- Configuration versioning

## Next Steps

1. **Complete Application Manifests**: Add remaining services from Levels 1-6
2. **GitOps Integration**: Set up ArgoCD applications
3. **CI/CD Pipeline**: Configure GitHub Actions
4. **Production Deployment**: Cloud provider setup
5. **Advanced Features**: Service mesh, security policies

## Support

For issues and questions:
- Check troubleshooting guide
- Review application logs
- Consult architecture documentation