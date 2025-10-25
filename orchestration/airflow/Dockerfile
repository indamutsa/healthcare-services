FROM apache/airflow:slim-2.7.3-python3.11

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    vim \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Switch to airflow user
USER airflow

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy configuration files
COPY config/ /opt/airflow/config/

# Copy custom plugins
COPY plugins/ /opt/airflow/plugins/

# Copy DAGs
COPY dags/ /opt/airflow/dags/

# Create necessary directories
RUN mkdir -p /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins

# Set environment variables
ENV AIRFLOW__CORE__LOAD_EXAMPLES=False
ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor
ENV AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres-airflow:5432/airflow
ENV AIRFLOW__CORE__FERNET_KEY=UKMzEm3yIuFYEq1y3-2FxGb6l6_kU5KDo5YN6RnGq3Q=
ENV AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
ENV AIRFLOW__WEBSERVER__EXPOSE_CONFIG=True

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["airflow", "webserver"]