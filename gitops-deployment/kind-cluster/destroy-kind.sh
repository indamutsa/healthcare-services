#!/bin/bash

# Kind Cluster Destruction Script
# This script destroys the local Kubernetes cluster

set -e

echo "🗑️  Destroying Kind cluster 'clinical-mlops'..."

# Check if cluster exists
if ! kind get clusters | grep -q "clinical-mlops"; then
    echo "⚠️  Cluster 'clinical-mlops' does not exist."
    exit 0
fi

# Delete the cluster
kind delete cluster --name clinical-mlops

echo "✅ Kind cluster 'clinical-mlops' has been destroyed."
echo ""
echo "💡 To recreate the cluster: ./setup-kind.sh"