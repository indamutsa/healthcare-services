#!/bin/bash

# GitOps Setup Script for Clinical Trials MLOps Platform
# This script sets up ArgoCD and deploys the GitOps applications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🚀 Setting up GitOps deployment for Clinical Trials MLOps Platform..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if we're connected to a Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Not connected to a Kubernetes cluster. Please set up your cluster first."
    echo "   You can use: ./kind-cluster/setup-kind.sh"
    exit 1
fi

echo "📋 Cluster Information:"
echo "   Cluster: $(kubectl config current-context)"
echo "   Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | cut -d' ' -f3)"
echo ""

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Install Argo Rollouts
echo "📦 Installing Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install Istio (optional - for advanced traffic management)
echo "📦 Installing Istio..."
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
sudo cp bin/istioctl /usr/local/bin/
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled

# Create namespaces for our applications
echo "📁 Creating application namespaces..."
for ns in infrastructure data-ingestion data-processing ml-pipeline orchestration observability; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    # Enable Istio injection for application namespaces
    kubectl label namespace "$ns" istio-injection=enabled --overwrite
    echo "   ✅ Created namespace: $ns"
done

# Get ArgoCD admin password
echo "🔐 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Apply ArgoCD applications
echo "📄 Applying ArgoCD applications..."
kubectl apply -f "$SCRIPT_DIR/../argocd/applications/"

# Wait for applications to sync
echo "⏳ Waiting for applications to sync..."
sleep 30

# Display setup information
echo ""
echo "✅ GitOps setup complete!"
echo ""
echo "🔗 Access Information:"
echo "   ArgoCD UI: https://localhost:8080 (use port-forward)"
echo "   ArgoCD Username: admin"
echo "   ArgoCD Password: $ARGOCD_PASSWORD"
echo ""
echo "📊 Application Status:"
echo "   To check application status: kubectl get applications -n argocd"
echo "   To check sync status: argocd app list"
echo ""
echo "🔧 Port Forwarding Commands:"
echo "   ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Grafana: kubectl port-forward svc/grafana -n observability 3000:3000"
echo "   Prometheus: kubectl port-forward svc/prometheus -n observability 9090:9090"
echo ""
echo "💡 Next Steps:"
echo "   1. Access ArgoCD UI and monitor application sync"
echo "   2. Check that all services are healthy"
echo "   3. Test the deployed applications"
echo "   4. Set up custom domains and TLS certificates"
echo ""
echo "📚 Useful Commands:"
echo "   # Get all ArgoCD applications"
echo "   kubectl get applications -n argocd"
echo ""
echo "   # Get application details"
echo "   argocd app get infrastructure"
echo ""
echo "   # Sync an application manually"
echo "   argocd app sync infrastructure"
echo ""
echo "   # Check application health"
echo "   argocd app health infrastructure"