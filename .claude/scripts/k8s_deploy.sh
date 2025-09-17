#!/bin/bash
# Kubernetes deployment script with validation and rollback

APP_NAME=${1:-myapp}
NAMESPACE=${2:-default}
IMAGE_TAG=${3:-latest}

echo "🚀 Deploying $APP_NAME to $NAMESPACE with tag $IMAGE_TAG"

# Pre-deployment validation
echo "🔍 Validating Kubernetes manifests..."
kubectl apply --dry-run=client -f k8s/ || {
    echo "❌ Manifest validation failed"
    exit 1
}

# Security scanning
if command -v trivy &> /dev/null; then
    echo "🔒 Scanning for security issues..."
    trivy config k8s/ || {
        echo "⚠️  Security issues found, continue? (y/N)"
        read -r response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 1
    }
fi

# Apply manifests
echo "📦 Applying manifests..."
kubectl apply -f k8s/ -n $NAMESPACE

# Wait for rollout
echo "⏳ Waiting for deployment rollout..."
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s || {
    echo "❌ Deployment failed, rolling back..."
    kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE
    exit 1
}

# Health check
echo "🏥 Running health checks..."
kubectl wait --for=condition=available deployment/$APP_NAME -n $NAMESPACE --timeout=120s || {
    echo "❌ Health check failed"
    exit 1
}

# Get service info
echo "✅ Deployment successful!"
kubectl get pods,svc -l app=$APP_NAME -n $NAMESPACE
echo "🌐 Service endpoints:"
kubectl get ingress -n $NAMESPACE