#!/bin/bash

echo "🏦 Initializing Payment Processing Platform Repository"
echo "=================================================="

# Create root directory
PROJECT_NAME="."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

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

# Applications directory structure
mkdir -p applications/payment-validator/src/main/java/com/payments/validator
mkdir -p applications/payment-validator/src/main/resources
mkdir -p applications/payment-validator/src/test/java/com/payments/validator
touch applications/payment-validator/pom.xml
touch applications/payment-validator/Dockerfile
touch applications/payment-validator/src/main/java/com/payments/validator/PaymentValidatorApplication.java
touch applications/payment-validator/src/main/resources/application.yml

mkdir -p applications/fraud-detector/src/main/java/com/payments/fraud
mkdir -p applications/fraud-detector/src/main/resources
mkdir -p applications/fraud-detector/src/test/java/com/payments/fraud
touch applications/fraud-detector/pom.xml
touch applications/fraud-detector/Dockerfile
touch applications/fraud-detector/src/main/java/com/payments/fraud/FraudDetectorApplication.java
touch applications/fraud-detector/src/main/resources/application.yml

mkdir -p applications/payment-processor/src/main/java/com/payments/processor
mkdir -p applications/payment-processor/src/main/resources
mkdir -p applications/payment-processor/src/test/java/com/payments/processor
touch applications/payment-processor/pom.xml
touch applications/payment-processor/Dockerfile
touch applications/payment-processor/src/main/java/com/payments/processor/PaymentProcessorApplication.java
touch applications/payment-processor/src/main/resources/application.yml

mkdir -p applications/status-reconciler/src/main/java/com/payments/reconciler
mkdir -p applications/status-reconciler/src/main/resources
mkdir -p applications/status-reconciler/src/test/java/com/payments/reconciler
touch applications/status-reconciler/pom.xml
touch applications/status-reconciler/Dockerfile
touch applications/status-reconciler/src/main/java/com/payments/reconciler/StatusReconcilerApplication.java
touch applications/status-reconciler/src/main/resources/application.yml

# Operations directory
mkdir -p operations/scripts/demo
mkdir -p operations/scripts/expect
mkdir -p operations/scripts/utilities
mkdir -p operations/jenkins/pipelines
mkdir -p operations/jenkins/jobs

# Demo scripts
touch operations/scripts/demo/payment_data_generator.py
touch operations/scripts/demo/status_update_simulator.py
touch operations/scripts/demo/payment_scenarios.py
touch operations/scripts/demo/monitor_payments.py
touch operations/scripts/demo/demo_setup.sh

# Expect scripts
touch operations/scripts/expect/mq_payment_setup.exp
touch operations/scripts/expect/payment_monitoring.exp
touch operations/scripts/expect/payment_automation.exp

# Utility scripts
touch operations/scripts/utilities/test_payment_flow.sh
touch operations/scripts/utilities/queue_manager.sh
touch operations/scripts/utilities/build_all_services.sh

# Jenkins pipelines
touch operations/jenkins/pipelines/Jenkinsfile.payment-deployment
touch operations/jenkins/pipelines/Jenkinsfile.payment-testing
touch operations/jenkins/pipelines/Jenkinsfile.fraud-detection

# Monitoring directory (for future implementation)
mkdir -p monitoring/prometheus/rules
mkdir -p monitoring/grafana/dashboards
mkdir -p monitoring/grafana/datasources
mkdir -p monitoring/elk/elasticsearch
mkdir -p monitoring/elk/logstash/pipeline
mkdir -p monitoring/elk/kibana

# Monitoring configuration files
touch monitoring/prometheus/prometheus.yml
touch monitoring/prometheus/rules/payment_alerts.yml
touch monitoring/prometheus/rules/fraud_alerts.yml
touch monitoring/grafana/dashboards/payment-overview.json
touch monitoring/grafana/dashboards/fraud-detection.json
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
touch docs/api/payment-api.md
touch docs/api/fraud-api.md
touch docs/api/status-api.md
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
mkdir -p test-data/payment-samples
mkdir -p test-data/fraud-scenarios
mkdir -p test-data/performance-test

touch test-data/payment-samples/valid-payments.json
touch test-data/payment-samples/invalid-payments.json
touch test-data/fraud-scenarios/suspicious-patterns.json
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
EOF

echo "✅ .gitignore created"

# Create basic README structure
cat > README.md << 'EOF'
# Payment Processing Platform

A comprehensive payment processing system built with IBM MQ, SpringBoot, and microservices architecture.

## Architecture Overview

This platform processes payments through a message-driven architecture with the following components:

- **Payment Validator**: Validates incoming payment requests
- **Fraud Detector**: Analyzes payments for suspicious patterns
- **Payment Processor**: Handles external payment processing
- **Status Reconciler**: Manages payment status updates and reconciliation

## Quick Start

```bash
# Build all services
./scripts/build-all.sh

# Start the platform
./scripts/start-all.sh

# Generate test data
python3 operations/scripts/demo/payment_data_generator.py

# Monitor the system
python3 operations/scripts/demo/monitor_payments.py
```

## Directory Structure

```
payment-processing-platform/
├── applications/           # SpringBoot microservices
├── infrastructure/         # IBM MQ and Docker configuration
├── operations/            # Scripts and automation
├── monitoring/            # Prometheus, Grafana, ELK stack
├── docs/                  # Documentation
├── config/                # Environment configurations
├── test-data/             # Sample data for testing
└── scripts/               # Utility scripts
```

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
MQ_QMGR_NAME=PAYMENT_QM
MQ_APP_USER=payment_app
MQ_APP_PASSWORD=payment123
MQ_ADMIN_PASSWORD=admin123

# Application Ports
MQ_PORT=1414
MQ_WEB_PORT=9443
PAYMENT_VALIDATOR_PORT=8080
FRAUD_DETECTOR_PORT=8081
PAYMENT_PROCESSOR_PORT=8082
STATUS_RECONCILER_PORT=8083

# Monitoring Ports
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
KIBANA_PORT=5601
ELASTICSEARCH_PORT=9200

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=payments
DB_USER=payment_user
DB_PASSWORD=payment_pass

# External API Configuration
EXTERNAL_PAYMENT_API_URL=https://api.payment-processor.com
FRAUD_DETECTION_API_URL=https://api.fraud-detection.com

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
echo "  • Applications: $(find applications -name "*.java" | wc -l) Java files across $(ls applications | wc -l) services"
echo "  • Operations scripts: $(find operations -name "*.py" -o -name "*.sh" -o -name "*.exp" | wc -l) files"
echo "  • Documentation: $(find docs -name "*.md" | wc -l) markdown files"
echo "  • Configuration: $(find config -type f | wc -l) config files"
echo "  • Total directories: $(find . -type d | wc -l)"
echo "  • Total files: $(find . -type f | wc -l)"
echo ""
echo "🚀 Ready to start development!"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. Review the folder structure"
echo "  3. Start implementing the components"
echo ""

cd ..
echo "✅ Repository initialization complete: ./$PROJECT_NAME/"