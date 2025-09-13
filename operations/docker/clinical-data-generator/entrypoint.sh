#!/bin/sh
set -e

DELAY="${GEN_START_DELAY:-30}"
echo "[clinical-data-generator] Startup delay: ${DELAY}s"
sleep "$DELAY"

exec python /app/clinical_data_generator.py

