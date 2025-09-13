FROM python:3.11-slim

WORKDIR /app

# System deps (if any) and Python libs
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy generator script
COPY operations/scripts/demo/clinical_data_generator.py /app/clinical_data_generator.py
COPY operations/docker/clinical-data-generator/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Defaults can be overridden by environment
ENV GEN_ENDPOINT=http://clinical-gateway:8080 \
    GEN_MODE=random \
    GEN_INTERVAL=1-5 \
    GEN_COUNT=0 \
    GEN_DATA_TYPE=random \
    GEN_START_DELAY=30

ENTRYPOINT ["/app/entrypoint.sh"]
