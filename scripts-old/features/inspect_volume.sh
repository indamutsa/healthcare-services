#!/bin/bash

# Inspect Docker Volume Contents

VOLUME_NAME="clinical-mlops_feature-data"

echo "============================================================"
echo "Inspecting Docker Volume: $VOLUME_NAME"
echo "============================================================"

# Check if volume exists
if docker volume ls | grep -q "$VOLUME_NAME"; then
    echo "✓ Volume exists"
    echo ""
    
    # List contents
    echo "Volume contents:"
    echo "------------------------------------------------------------"
    docker run --rm -v $VOLUME_NAME:/data alpine:latest ls -lah /data
    
    echo ""
    echo "Files detail:"
    echo "------------------------------------------------------------"
    docker run --rm -v $VOLUME_NAME:/data alpine:latest find /data -type f -exec ls -lh {} \;
    
    echo ""
    echo "Total size:"
    echo "------------------------------------------------------------"
    docker run --rm -v $VOLUME_NAME:/data alpine:latest du -sh /data
    
else
    echo "✗ Volume does not exist"
    echo ""
    echo "Create it with: docker volume create $VOLUME_NAME"
fi