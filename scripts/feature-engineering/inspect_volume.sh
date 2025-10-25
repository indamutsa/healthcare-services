#!/bin/bash
#
# Inspect the feature store Docker volume
#

set -euo pipefail

FEATURE_ENGINEERING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd "${FEATURE_ENGINEERING_SCRIPT_DIR}/../common" && pwd)"

source "${COMMON_DIR}/config.sh"
source "${COMMON_DIR}/utils.sh"

DEFAULT_VOLUME_NAME="clinical-trials-service_feature-data"
VOLUME_NAME="${1:-$DEFAULT_VOLUME_NAME}"

print_header "Inspecting Feature Store Volume"
echo "Volume Name: ${VOLUME_NAME}"
echo ""

if ! docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_NAME}$"; then
    log_error "Volume '${VOLUME_NAME}' not found."
    echo ""
    echo "Available volumes:"
    docker volume ls
    echo ""
    echo "Tip: override volume name -> ./inspect_volume.sh <volume-name>"
    exit 1
fi

log_success "Volume found"
echo ""

echo "Volume contents:"
echo "------------------------------------------------------------"
docker run --rm -v "${VOLUME_NAME}:/data" alpine:3.19 ls -lah /data || true

echo ""
echo "Files detail:"
echo "------------------------------------------------------------"
docker run --rm -v "${VOLUME_NAME}:/data" alpine:3.19 sh -c "find /data -maxdepth 2 -type f -exec ls -lh {} \;" || true

echo ""
echo "Total size:"
echo "------------------------------------------------------------"
docker run --rm -v "${VOLUME_NAME}:/data" alpine:3.19 du -sh /data || true

echo ""
log_info "Inspection complete."
