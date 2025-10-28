#!/bin/bash

set -e

# Configuration
NAMESPACE="clinical-mlops"
ENVIRONMENT="${1:-production}"
HELM_CHART_PATH="$(pwd)/helm-charts/clinical-mlops"
VALUES_FILE="values-${ENVIRONMENT}.yaml"

echo "🚀 Deploying Clinical MLOps Platform to ${ENVIRONMENT}..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed."; exit 1; }

# Create namespace
echo "📦 Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "📋 Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Istio (if not already installed)
echo "🌐 Installing Istio..."
if ! helm list -n istio-system | grep -q "istio-base"; then
    helm install istio-base istio/base -n istio-system --create-namespace
    helm install istiod istio/istiod -n istio-system --wait
    helm install istio-ingressgateway istio/gateway -n istio-system --wait
fi

# Install Argo Rollouts (if not installed)
echo "🎲 Installing Argo Rollouts..."
if ! kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
    kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
fi

# Update Helm dependencies
echo "🔄 Updating Helm dependencies..."
cd $HELM_CHART_PATH
helm dependency update

# Deploy storage classes and volumes
echo "💾 Deploying storage configuration..."
kubectl apply -f ../kubernetes-manifests/storage/storage-classes.yaml
kubectl apply -f ../kubernetes-manifests/storage/persistent-volumes.yaml

# Deploy monitoring stack
echo "📊 Deploying monitoring stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.adminPassword=${GRAFANA_PASSWORD:-admin123} \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=monitoring

# Deploy OpenSearch for logging
echo "📝 Deploying OpenSearch..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opensearch
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opensearch
  template:
    metadata:
      labels:
        app: opensearch
    spec:
      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.12.0
        env:
        - name: discovery.type
          value: single-node
        - name: bootstrap.memory_lock
          value: "true"
        - name: "OPENSEARCH_JAVA_OPTS"
          value: "-Xms1g -Xmx1g"
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        volumeMounts:
        - name: opensearch-data
          mountPath: /usr/share/opensearch/data
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
      volumes:
      - name: opensearch-data
        persistentVolumeClaim:
          claimName: opensearch-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: opensearch
  namespace: monitoring
spec:
  selector:
    app: opensearch
  ports:
  - port: 9200
    targetPort: 9200
    name: http
  - port: 9300
    targetPort: 9300
    name: transport
EOF

# Deploy the main application using Helm
echo "🚀 Deploying main application..."
VALUES_ARGS=""
if [ -f "$VALUES_FILE" ]; then
    VALUES_ARGS="--values $VALUES_FILE"
fi

helm upgrade --install clinical-mlops . \
  --namespace $NAMESPACE \
  --create-namespace \
  $VALUES_ARGS \
  --set global.environment=$ENVIRONMENT \
  --set global.namespace=$NAMESPACE \
  --wait \
  --timeout 15m

# Deploy Istio configuration
echo "🌐 Deploying Istio configuration..."
kubectl apply -f ../istio/gateway/
kubectl apply -f ../istio/virtual-services/
kubectl apply -f ../istio/destination-rules/
kubectl apply -f ../istio/policies/

# Deploy Argo Rollouts configurations
echo "🎲 Deploying Argo Rollouts configurations..."
kubectl apply -f ../argo-rollouts/canary-strategies/
kubectl apply -f ../argo-rollouts/blue-green-strategies/
kubectl apply -f ../argo-rollouts/analysis-templates/

# Deploy security configurations
echo "🔒 Deploying security configurations..."
kubectl apply -f ../security/network-policies/
kubectl apply -f ../security/psp/

# Set up backup cronjobs
echo "💾 Setting up backup jobs..."
kubectl apply -f ../kubernetes-manifests/storage/backup-cronjob.yaml

# Deploy LocalStack (only for development/staging)
if [ "$ENVIRONMENT" != "production" ]; then
    echo "🔧 Deploying LocalStack..."
    cd ../localstack
    docker-compose up -d
    
    # Initialize LocalStack services
    sleep 30
    ./init-scripts/setup-services.sh
fi

# Wait for all deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment --all -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment --all -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment --all -n istio-system

# Run health checks
echo "🏥 Running health checks..."
./scripts/health-checks.sh $ENVIRONMENT

# Display access information
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "Grafana: http://$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000"
echo "Prometheus: http://$(kubectl get svc prometheus-server -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9090"
echo "MLflow: http://mlflow.$NAMESPACE.svc.cluster.local:5000"
echo "Clinical Gateway API: http://api.clinical-mlops.local"
echo ""
echo "🔐 Authentication:"
echo "Grafana Username: admin"
echo "Grafana Password: ${GRAFANA_PASSWORD:-admin123}"
echo ""
echo "📈 Monitoring:"
echo "View logs: kubectl logs -f deployment/monitoring-service -n $NAMESPACE"
echo "Check pods: kubectl get pods -n $NAMESPACE"
echo "Check services: kubectl get services -n $NAMESPACE"
echo ""
echo "🔄 GitOps:"
echo "For production deployments, use ArgoCD at: http://$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"

# Generate deployment report
echo "📋 Generating deployment report..."
cat > /tmp/deployment-report.json <<EOF
{
  "deployment": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "namespace": "$NAMESPACE",
    "version": "$(helm list -n $NAMESPACE -q -f clinical-mlops | xargs helm get values -n $NAMESPACE -o json | jq -r '.version // \"unknown\"')"
  },
  "components": {
    "infrastructure": {
      "status": "$(kubectl get statefulsets -n $NAMESPACE -o jsonpath='{.items[*].status.readyReplicas}' | wc -w) ready",
      "services": "$(kubectl get services -n $NAMESPACE --no-headers | wc -l)"
    },
    "applications": {
      "deployments": "$(kubectl get deployments -n $NAMESPACE --no-headers | wc -l)",
      "pods": "$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)",
      "ready_pods": "$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)"
    },
    "monitoring": {
      "prometheus": "$(kubectl get deployment prometheus-server -n monitoring -o jsonpath='{.status.readyReplicas}')",
      "grafana": "$(kubectl get deployment grafana -n monitoring -o jsonpath='{.status.readyReplicas}')"
    }
  },
  "endpoints": {
    "grafana": "http://$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000",
    "prometheus": "http://$(kubectl get svc prometheus-server -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9090",
    "api_gateway": "http://api.clinical-mlops.local"
  }
}
EOF

echo "Deployment report saved to /tmp/deployment-report.json"

# Send notification (if configured)
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    echo "📢 Sending deployment notification..."
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ Clinical MLOps Platform deployed to $ENVIRONMENT successfully!\"}" \
        $SLACK_WEBHOOK_URL
fi

echo "🚀 Ready to serve clinical trials workloads!"