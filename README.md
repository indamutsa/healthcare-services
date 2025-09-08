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
