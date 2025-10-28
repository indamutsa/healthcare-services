#!/bin/bash

set -e

# Configuration
NAMESPACE="clinical-mlops"
ARGOCD_NAMESPACE="argocd"
HELM_REPO_URL="https://github.com/$(git config remote.origin.url | sed 's/.*://')"
HELM_REPO_BRANCH="${1:-main}"

echo "🚀 Setting up complete GitOps workflow for Clinical MLOps Platform..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed."; exit 1; }
command -v argocd >/dev/null 2>&1 || { echo "❌ argocd CLI is required but not installed."; exit 1; }

# Create namespaces
echo "📦 Creating namespaces..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "🔄 Installing ArgoCD..."
if ! helm repo add argo https://argoproj.github.io/argo-helm; then
    echo "ArgoCD helm repo already exists"
fi
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace $ARGOCD_NAMESPACE \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set server.config.repositories[0].type=git \
  --set server.config.repositories[0].url=$HELM_REPO_URL \
  --set server.config.repositories[0].name=clinical-mlops-repo \
  --set server.config.repositories[0].branch=$HELM_REPO_BRANCH \
  --set notifications.enabled=true \
  --wait \
  --timeout 10m

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE

# Get ArgoCD admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD URL: $(kubectl get svc argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
echo "ArgoCD Username: admin"
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Install Argo Rollouts
echo "🎲 Installing Argo Rollouts..."
if ! kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
    kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
fi

# Install Istio
echo "🌐 Installing Istio service mesh..."
if ! helm repo add istio https://istio-release.storage.googleapis.com/charts; then
    echo "Istio helm repo already exists"
fi
helm repo update

helm upgrade --install istio-base istio/base \
  --namespace istio-system \
  --create-namespace \
  --wait

helm upgrade --install istiod istio/istiod \
  --namespace istio-system \
  --create-namespace \
  --wait

helm upgrade --install istio-ingressgateway istio/gateway \
  --namespace istio-system \
  --create-namespace \
  --wait

# Install Prometheus Stack
echo "📊 Installing Prometheus monitoring stack..."
if ! helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; then
    echo "Prometheus helm repo already exists"
fi
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.adminPassword=admin123 \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=monitoring \
  --wait

# Create ArgoCD Applications for each component
echo "📋 Creating ArgoCD applications..."

# Infrastructure Application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: clinical-mlops-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $HELM_REPO_URL
    targetRevision: $HELM_REPO_BRANCH
    path: gitops-deployment/helm-charts/clinical-mlops
    helm:
      valueFiles:
      - values.yaml
      parameters:
      - name: infrastructure.enabled
        value: "true"
      - name: data-ingestion.enabled
        value: "false"
      - name: data-processing.enabled
        value: "false"
      - name: feature-engineering.enabled
        value: "false"
      - name: ml-pipeline.enabled
        value: "false"
      - name: orchestration.enabled
        value: "false"
      - name: observability.enabled
        value: "false"
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

# Application Set for all services
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: clinical-mlops-services
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - name: data-ingestion
        enabled: true
      - name: data-processing
        enabled: true
      - name: feature-engineering
        enabled: true
      - name: ml-pipeline
        enabled: true
      - name: orchestration
        enabled: true
      - name: observability
        enabled: true
  template:
    metadata:
      name: 'clinical-mlops-{{name}}'
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: $HELM_REPO_URL
        targetRevision: $HELM_REPO_BRANCH
        path: gitops-deployment/helm-charts/clinical-mlops
        helm:
          valueFiles:
          - values.yaml
          parameters:
          - name: '{{name}}.enabled'
            value: '{{enabled}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: $NAMESPACE
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
        - PrunePropagationPolicy=foreground
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
EOF

# Create ArgoCD Project for better organization
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: clinical-mlops
  namespace: argocd
spec:
  description: Clinical MLOps Platform
  sourceRepos:
  - $HELM_REPO_URL
  destinations:
  - namespace: $NAMESPACE
    server: https://kubernetes.default.svc
  - namespace: istio-system
    server: https://kubernetes.default.svc
  - namespace: monitoring
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

# Install certificates for HTTPS
echo "🔒 Setting up certificates..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@clinical-mlops.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
EOF

# Set up monitoring for ArgoCD
echo "📈 Setting up ArgoCD monitoring..."
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  endpoints:
  - port: metrics
EOF

# Configure GitOps webhook
echo "🪝 Setting up GitOps webhook..."
cat <<EOF
To complete the GitOps setup, add this webhook to your GitHub repository:

Webhook URL: $(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/api/webhook
Content type: application/json
Secret: $(kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.webhook\.secret}' | base64 -d)
Events:
  - Push
  - Pull Request
  - Release

Payload example:
{
  "ref": "refs/heads/main",
  "repository": {
    "name": "clinical-mlops",
    "full_name": "your-org/clinical-mlops"
  },
  "pusher": {
    "name": "your-username"
  },
  "commits": [
    {
      "id": "commit-sha",
      "message": "Deploy new version",
      "author": {
        "name": "your-username"
      }
    }
  ]
}
EOF

# Create utility scripts
echo "📝 Creating utility scripts..."

# Sync script
cat > /tmp/gitops-sync.sh <<'EOF'
#!/bin/bash
NAMESPACE="clinical-mlops"
ARGOCD_NAMESPACE="argocd"

echo "🔄 Syncing all ArgoCD applications..."

# Get all applications in the clinical-mlops project
APPS=$(kubectl get applications -n $ARGOCD_NAMESPACE -l app.kubernetes.io/part-of=clinical-mlops -o jsonpath='{.items[*].metadata.name}')

for app in $APPS; do
    echo "Syncing $app..."
    argocd app sync $app -n $ARGOCD_NAMESPACE --force
done

echo "✅ All applications synced"
EOF
chmod +x /tmp/gitops-sync.sh

# Rollback script
cat > /tmp/gitops-rollback.sh <<'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <app-name> [revision]"
    exit 1
fi

APP_NAME=$1
REVISION=${2:-HEAD~1}
NAMESPACE="clinical-mlops"
ARGOCD_NAMESPACE="argocd"

echo "🔙 Rolling back $APP_NAME to $REVISION..."

argocd app rollback $APP_NAME $REVISION -n $ARGOCD_NAMESPACE

echo "✅ Rollback initiated for $APP_NAME"
EOF
chmod +x /tmp/gitops-rollback.sh

echo ""
echo "🎉 Complete GitOps setup finished!"
echo ""
echo "📋 Next steps:"
echo "1. Configure GitHub webhook using the URL provided above"
echo "2. Access ArgoCD UI at: $(kubectl get svc argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
echo "3. Login with username 'admin' and password: $ARGOCD_PASSWORD"
echo "4. Monitor deployments in the ArgoCD UI"
echo "5. Use the provided scripts for manual sync and rollback operations"
echo ""
echo "🔧 Useful commands:"
echo "- Sync all apps: argocd app sync -l app.kubernetes.io/part-of=clinical-mlops"
echo "- Check app status: argocd app get <app-name>"
echo "- View app logs: argocd app logs <app-name>"
echo "- Manual rollback: argocd app rollback <app-name> <revision>"