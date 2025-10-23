#!/bin/bash
#
# Monitor feature engineering pipeline execution
# Shows real-time progress and metrics
#

set -e

echo "=========================================="
echo "Feature Engineering Pipeline Monitor"
echo "=========================================="
echo ""

CONTAINER_NAME="feature-engineering"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✗ Container '$CONTAINER_NAME' is not running"
    echo ""
    echo "Start it with:"
    echo "  docker-compose --profile feature-engineering up -d"
    exit 1
fi

echo "✓ Container is running"
echo ""

# Follow logs
echo "Following logs (Ctrl+C to stop)..."
echo "=========================================="
echo ""

docker logs -f "$CONTAINER_NAME"