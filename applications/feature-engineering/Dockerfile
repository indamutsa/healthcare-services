FROM apache/spark:3.5.4-java17

USER root

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Copy application code
COPY config /app/config
COPY features /app/features
COPY utils /app/utils
COPY pipeline.py /app/
COPY feature_store.py /app/

# Create data directory for metadata
RUN mkdir -p /app/data && chmod 777 /app/data

# Set working directory
WORKDIR /app

# Set Python path
ENV PYTHONPATH=/app:$PYTHONPATH

# Default command
CMD ["python3", "pipeline.py"]