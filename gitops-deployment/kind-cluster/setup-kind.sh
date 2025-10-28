#!/bin/bash

# Kind Cluster Setup Script for Clinical Trials MLOps Platform
# This script creates a local Kubernetes cluster using Kind

set -e

echo "🚀 Setting up Kind cluster for Clinical Trials MLOps Platform..."

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    echo "❌ Kind is not installed. Please install Kind first:"
    echo "   https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if cluster already exists
if kind get clusters | grep -q "clinical-mlops"; then
    echo "⚠️  Cluster 'clinical-mlops' already exists. Deleting..."
    kind delete cluster --name clinical-mlops
fi

# Create the cluster
echo "📦 Creating Kind cluster 'clinical-mlops'..."
kind create cluster --name clinical-mlops --config kind-config.yaml

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ingress controller
echo "🌐 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

# Install metrics server for HPA
echo "📊 Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for Kind
kubectl patch deployment metrics-server -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp", "--secure-port=4443", "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname", "--kubelet-use-node-status-port", "--metric-resolution=15s", "--kubelet-insecure-tls"]}]}}}}'

# Create namespaces for our applications
echo "📁 Creating namespaces..."
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace data-ingestion --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace data-processing --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ml-pipeline --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace orchestration --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Set up local storage class
echo "💾 Setting up local storage..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Display cluster info
echo ""
echo "✅ Kind cluster setup complete!"
echo ""
echo "📋 Cluster Information:"
echo "   Cluster Name: clinical-mlops"
echo "   Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | cut -d' ' -f3)"
echo "   Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo ""
echo "🔧 Next Steps:"
echo "   1. Install ArgoCD: kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
echo "   2. Get ArgoCD admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo "   3. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "🌐 Available Services:"
echo "   - Ingress Controller: http://localhost:30080"
echo "   - Grafana (when deployed): http://localhost:30300"
echo "   - Prometheus (when deployed): http://localhost:30900"
echo "   - OpenSearch Dashboards (when deployed): http://localhost:30560"
echo ""
echo "💡 To destroy the cluster: ./destroy-kind.sh"