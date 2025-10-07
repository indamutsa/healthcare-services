#!/bin/bash
# Multi-stage Docker build with security scanning

APP_NAME=${1:-myapp}
TAG=${2:-latest}
REGISTRY=${3:-""}

echo "🐳 Building Docker image for $APP_NAME:$TAG"

# Security scan Dockerfile
if command -v hadolint &> /dev/null; then
    echo "🔍 Linting Dockerfile..."
    hadolint Dockerfile || {
        echo "⚠️  Dockerfile issues found, continue? (y/N)"
        read -r response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 1
    }
fi

# Build image
echo "🔨 Building image..."
docker build \
    --tag $APP_NAME:$TAG \
    --tag $APP_NAME:latest \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    .

# Security scan image
if command -v trivy &> /dev/null; then
    echo "🔒 Scanning image for vulnerabilities..."
    trivy image --exit-code 1 --severity HIGH,CRITICAL $APP_NAME:$TAG || {
        echo "❌ Critical vulnerabilities found!"
        echo "🗑️  Remove image? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            docker rmi $APP_NAME:$TAG
            exit 1
        fi
    }
fi

# Push to registry if specified
if [ -n "$REGISTRY" ]; then
    echo "📤 Pushing to registry..."
    docker tag $APP_NAME:$TAG $REGISTRY/$APP_NAME:$TAG
    docker push $REGISTRY/$APP_NAME:$TAG
    echo "✅ Pushed $REGISTRY/$APP_NAME:$TAG"
fi

# Image info
echo "✅ Build complete!"
echo "📊 Image info:"
docker images $APP_NAME:$TAG --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Cleanup
echo "🧹 Cleanup dangling images..."
docker image prune -f