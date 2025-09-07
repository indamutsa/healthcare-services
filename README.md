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
