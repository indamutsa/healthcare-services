#!/bin/bash

echo "🏥 Initializing Healthcare Clinical Trials Platform Repository"
echo "==========================================================="

# Create root directory
PROJECT_NAME="."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

rm -rf config docker-compose.yml docs fix-rename.sh infrastructure monitoring operations README.md rename.sh requirements.txt scripts test-data

# Initialize git repository
git init
echo "✅ Git repository initialized"

# Create main project structure
echo "📁 Creating folder structure..."

# Root configuration files
touch README.md
touch .gitignore
touch docker-compose.yml
touch .env
touch requirements.txt

# Infrastructure directory
mkdir -p infrastructure/docker/ibm-mq/config
touch infrastructure/docker/ibm-mq/Dockerfile
touch infrastructure/docker/ibm-mq/config/mq.mqsc
touch infrastructure/docker/ibm-mq/config/qm.ini

# We initialized 2 spring applications with spring initialzr:
# For both services, here are the Spring Initializr dependencies you should select:

# ## Core Dependencies (Both Services)

# **Search for and add these:**

# 1. **Spring Web** (`web`)
#    - Provides REST endpoints and HTTP server
   
# 2. **Spring for Apache ActiveMQ 5** (`activemq`)
#    - JMS support and message templates
   
# 3. **Spring Boot Actuator** (`actuator`)
#    - Health checks and monitoring endpoints
   
# 4. **Spring Boot DevTools** (`devtools`)
#    - Development tools and hot reloading
   
# 5. **Lombok** (`lombok`)
#    - Reduces boilerplate code
   
# 6. **Spring Boot Starter Test** (`test`)
#    - Testing framework
   
# 7. **Prometheus** (`prometheus`)
#    - Metrics for monitoring

# ## Additional Dependencies by Service

# **Clinical Data Gateway (Service 1):**
# - **Spring Boot Starter Validation** (`validation`)
#   - For validating incoming clinical data

# **Lab Results Processor (Service 2):**
# - **Spring Data JPA** (`jpa`)
#   - For storing processed results
# - **H2 Database** (`h2`)
#   - In-memory database for development

# ## Spring Initializr Settings

# **Both services:**
# - **Spring Boot Version:** 3.2.x (latest stable)
# - **Language:** Java
# - **Group:** com.healthcare
# - **Java Version:** 17
# - **Packaging:** Jar

# **Service 1:**
# - **Artifact:** clinical-data-gateway

# **Service 2:**
# - **Artifact:** lab-results-processor

# ## Note on IBM MQ

# Spring Initializr doesn't have IBM MQ directly, so we'll add that dependency manually to the pom.xml later:

# ```xml
# <dependency>
#     <groupId>com.ibm.mq</groupId>
#     <artifactId>mq-jms-spring-boot-starter</artifactId>
#     <version>3.2.4</version>
# </dependency>
```

# Operations directory
mkdir -p operations/scripts/demo
mkdir -p operations/scripts/expect
mkdir -p operations/scripts/utilities
mkdir -p operations/jenkins/pipelines
mkdir -p operations/jenkins/jobs

# Demo scripts
touch operations/scripts/demo/clinical_data_generator.py
touch operations/scripts/demo/lab_results_simulator.py
touch operations/scripts/demo/clinical_scenarios.py
touch operations/scripts/demo/monitor_clinical_system.py
touch operations/scripts/demo/demo_setup.sh

# Expect scripts
touch operations/scripts/expect/mq_clinical_setup.exp
touch operations/scripts/expect/clinical_monitoring.exp
touch operations/scripts/expect/clinical_automation.exp

# Utility scripts
touch operations/scripts/utilities/test_clinical_flow.sh
touch operations/scripts/utilities/queue_manager.sh
touch operations/scripts/utilities/build_all_services.sh

# Jenkins pipelines
touch operations/jenkins/pipelines/Jenkinsfile.clinical-deployment
touch operations/jenkins/pipelines/Jenkinsfile.clinical-testing
touch operations/jenkins/pipelines/Jenkinsfile.data-quality

# Monitoring directory
mkdir -p monitoring/prometheus/rules
mkdir -p monitoring/grafana/dashboards
mkdir -p monitoring/grafana/datasources
mkdir -p monitoring/elk/elasticsearch
mkdir -p monitoring/elk/logstash/pipeline
mkdir -p monitoring/elk/kibana

# Monitoring configuration files
touch monitoring/prometheus/prometheus.yml
touch monitoring/prometheus/rules/clinical_alerts.yml
touch monitoring/prometheus/rules/data_quality_alerts.yml
touch monitoring/grafana/dashboards/clinical-overview.json
touch monitoring/grafana/dashboards/lab-results-processing.json
touch monitoring/grafana/datasources/prometheus.yml

# Documentation directory
mkdir -p docs/architecture
mkdir -p docs/api
mkdir -p docs/deployment
mkdir -p docs/troubleshooting

touch docs/README.md
touch docs/architecture/system-overview.md
touch docs/architecture/message-flows.md
touch docs/architecture/queue-design.md
touch docs/api/clinical-gateway-api.md
touch docs/api/lab-processor-api.md
touch docs/deployment/docker-setup.md
touch docs/deployment/kubernetes-setup.md
touch docs/troubleshooting/common-issues.md
touch docs/troubleshooting/performance-tuning.md

# Configuration directory
mkdir -p config/environments
mkdir -p config/security
mkdir -p config/monitoring

touch config/environments/development.yml
touch config/environments/staging.yml
touch config/environments/production.yml
touch config/security/certificates.md
touch config/monitoring/alerts.yml

# Test data directory
mkdir -p test-data/clinical-samples
mkdir -p test-data/lab-result-scenarios
mkdir -p test-data/performance-test

touch test-data/clinical-samples/valid-clinical-data.json
touch test-data/clinical-samples/invalid-clinical-data.json
touch test-data/lab-result-scenarios/lab-patterns.json
touch test-data/performance-test/high-volume-data.json

# Scripts directory in root
mkdir -p scripts
touch scripts/start-all.sh
touch scripts/stop-all.sh
touch scripts/clean-all.sh
touch scripts/build-all.sh
touch scripts/test-complete-flow.sh

# Create .gitignore content
cat > .gitignore << 'EOF'
# Compiled class files
*.class
target/
*.jar
*.war
*.ear

# IDE files
.idea/
.vscode/
*.iml
*.ipr
*.iws

# OS files
.DS_Store
Thumbs.db

# Log files
*.log
logs/

# Docker volumes
**/data/
**/logs/

# Environment variables
.env.local
.env.production

# Maven
.mvn/
mvnw
mvnw.cmd

# Temporary files
*.tmp
*.temp

# Database files
*.db
*.sqlite

# Security
*.pem
*.key
private/

# Generated files
generated/
build/
dist/

# Test reports
test-results/
coverage/

# Healthcare data (HIPAA compliance)
**/patient-data/
**/phi/
**/clinical-records/
EOF

echo "✅ .gitignore created"

# Create basic README structure
cat > README.md << 'EOF'
# Healthcare Clinical Trials Platform

A comprehensive clinical trials data processing system built with IBM MQ, SpringBoot, and microservices architecture for healthcare environments.

## Architecture Overview

This platform processes clinical trial data through a message-driven architecture with the following components:

- **Clinical Data Gateway**: Receives and validates clinical trial data via REST API
- **Lab Results Processor**: Processes lab results, updates EMR systems, and handles audit logging

## Quick Start

```bash
# Build all services
./scripts/build-all.sh

# Start the platform
./scripts/start-all.sh

# Generate test clinical data
python3 operations/scripts/demo/clinical_data_generator.py

# Monitor the system
python3 operations/scripts/demo/monitor_clinical_system.py
```

## Directory Structure

```
healthcare-clinical-trials-platform/
 applications/           # SpringBoot microservices
 infrastructure/         # IBM MQ and Docker configuration
 operations/            # Scripts and automation
 monitoring/            # Prometheus, Grafana, ELK stack
 docs/                  # Documentation
 config/                # Environment configurations
 test-data/             # Sample clinical data for testing
└── scripts/               # Utility scripts
```

## Clinical Data Flow

```
Clinical Trial Sites → REST API → JMS Template → IBM MQ → Lab Processor → EMR/Audit
```

## Use Cases

- **Lab Results Processing**: Blood work, COVID tests, genomic sequencing
- **Clinical Trial Data**: Patient vitals, medication adherence, adverse events
- **EMR Integration**: Reliable data transmission to Electronic Medical Records
- **Compliance & Auditing**: HIPAA-compliant audit trails and data integrity
- **Analytics Pipeline**: Data processing for research and early detection models

## Documentation

- [System Architecture](docs/architecture/system-overview.md)
- [Message Flows](docs/architecture/message-flows.md)
- [API Documentation](docs/api/)
- [Deployment Guide](docs/deployment/)

## Development

### Prerequisites

- Java 17+
- Docker & Docker Compose
- Python 3.8+
- Maven 3.6+

### Building

```bash
# Build all SpringBoot services
mvn clean package -f applications/

# Build Docker images
docker-compose build
```

### Testing

```bash
# Run unit tests
mvn test -f applications/

# Run integration tests
./scripts/test-complete-flow.sh
```

## Monitoring

- Grafana Dashboard: http://localhost:3000
- Prometheus Metrics: http://localhost:9090
- Kibana Logs: http://localhost:5601

## Compliance

This system is designed with healthcare compliance in mind:
- HIPAA-compliant data handling
- Audit trails for all clinical data processing
- Secure message transmission via IBM MQ
- Data integrity verification

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - see LICENSE file for details
EOF

echo "✅ README.md created"

# Create basic environment file
cat > .env << 'EOF'
# MQ Configuration
MQ_QMGR_NAME=CLINICAL_QM
MQ_APP_USER=clinical_app
MQ_APP_PASSWORD=clinical123
MQ_ADMIN_PASSWORD=admin123

# Application Ports
MQ_PORT=1414
MQ_WEB_PORT=9443
CLINICAL_DATA_GATEWAY_PORT=8080
LAB_RESULTS_PROCESSOR_PORT=8081

# Monitoring Ports
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
KIBANA_PORT=5601
ELASTICSEARCH_PORT=9200

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=clinical_trials
DB_USER=clinical_user
DB_PASSWORD=clinical_pass

# External API Configuration
EMR_SYSTEM_API_URL=https://api.emr-system.com
LAB_SYSTEM_API_URL=https://api.lab-system.com
CLINICAL_TRIAL_API_URL=https://api.clinical-trials.com

# Healthcare Compliance
HIPAA_AUDIT_ENABLED=true
DATA_ENCRYPTION_ENABLED=true
PHI_MASKING_ENABLED=true

# Environment
ENVIRONMENT=development
LOG_LEVEL=INFO
SPRING_PROFILES_ACTIVE=development
EOF

echo "✅ .env file created"

# Display the created structure
echo ""
echo "📁 Project structure created successfully!"
echo ""
echo "📊 Summary:"
echo "  • Root files: $(find . -maxdepth 1 -type f | wc -l) files"
echo "  • Applications: 2 SpringBoot services (clinical-data-gateway, lab-results-processor)"
echo "  • Operations scripts: $(find operations -name "*.py" -o -name "*.sh" -o -name "*.exp" | wc -l) files"
echo "  • Documentation: $(find docs -name "*.md" | wc -l) markdown files"
echo "  • Configuration: $(find config -type f | wc -l) config files"
echo "  • Total directories: $(find . -type d | wc -l)"
echo "  • Total files: $(find . -type f | wc -l)"
echo ""
echo "🏥 Healthcare Clinical Trials Platform Ready!"
echo ""
echo "Key Features:"
echo "  • HIPAA-compliant data processing"
echo "  • Clinical trial data validation"
echo "  • Lab results processing pipeline"
echo "  • EMR system integration"
echo "  • Comprehensive audit trails"
echo ""
echo "Next steps:"
echo "  1. Review the folder structure"
echo "  2. Configure IBM MQ for clinical data queues"
echo "  3. Implement the SpringBoot services"
echo "  4. Set up monitoring and compliance logging"
echo ""

echo "✅ Healthcare repository initialization complete!"