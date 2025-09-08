# Healthcare Clinical Trials Platform

A comprehensive clinical trials data processing system built with **IBM MQ**, **Spring Boot**, and **microservices architecture** for healthcare environments.

## Architecture Overview

This platform processes clinical trial data through a **message-driven architecture**:

```
Clinical Trial Sites → REST API → Spring JMS → IBM MQ → Lab Processor → EMR/Audit
```

**Core Components:**
- **Clinical Data Gateway** (Port 8080): Receives and validates clinical trial data via REST API
- **Lab Results Processor** (Port 8081): Processes lab results, updates EMR systems, and handles audit logging
- **IBM MQ**: Message broker for reliable clinical data transmission
- **Monitoring Stack**: Prometheus, Grafana, ELK for system observability

## Quick Start (Container-Based Development)

### 1. Setup Development Environment
```bash
# Open VS Code with Alpine container (clean machine approach)
# Run terminal enhancement
chmod +x enhance-terminal.sh
./enhance-terminal.sh

# Setup complete development environment
chmod +x alpine-setup.sh
./alpine-setup.sh
```

### 2. Start the Platform
```bash
# Activate development environment
source .pyenv/bin/activate

# Start IBM MQ container
docker-compose up -d

# Build and run Clinical Data Gateway
cd applications/clinical-data-gateway
mvn clean package
java -jar target/clinical-data-gateway-1.0.0.jar

# Generate test clinical data (new terminal)
python operations/scripts/demo/clinical_data_generator.py --count 10 --interval 2-5
```

### 3. Verify the Demo
```bash
# Test gateway health
curl http://localhost:8080/api/clinical/health

# View processing statistics
curl http://localhost:8080/api/clinical/stats
```

## Project Structure

```
clinical-trials-service/
├── .devcontainer/              # VS Code container configuration
├── applications/               # Spring Boot microservices
│   ├── clinical-data-gateway/  # REST API & JMS producer
│   └── lab-results-processor/  # JMS consumer & data processor
├── operations/                 # Demo scripts and automation
│   └── scripts/demo/          # Clinical data generator
├── infrastructure/             # IBM MQ Docker configuration  
├── monitoring/                 # Prometheus, Grafana, ELK stack
├── config/                     # Environment configurations
├── docs/                       # API and architecture documentation
├── test-data/                  # Sample clinical data for testing
└── scripts/                    # Build and deployment utilities
```

## Clinical Data Types

The system processes four types of clinical data:

1. **Patient Demographics** (15%): Age, gender, weight, height, study enrollment
2. **Vital Signs** (40%): Blood pressure, heart rate, temperature, oxygen saturation
3. **Lab Results** (30%): Blood glucose, cholesterol, hemoglobin, liver enzymes
4. **Adverse Events** (15%): Side effects, severity, relation to study drug

## Development Workflow

### Container-First Approach
This project uses **containerized development** to avoid installing tools locally:

```bash
# 1. VS Code + Alpine container (clean slate)
# 2. Enhanced terminal (ZSH + autosuggestions)  
# 3. Complete toolchain (Java 17, Maven, Python, Docker)
# 4. Ready for demo in minutes
```

### Build & Test
```bash
# Build all services
./scripts/build-all.sh

# Run integration tests
./scripts/test-complete-flow.sh

# Clean build artifacts
./scripts/clean-all.sh
```

## Technology Stack

**Backend:**
- **Java 17** with Spring Boot 3.2
- **Spring JMS** for message processing
- **IBM MQ** for reliable messaging
- **Maven** for build management

**Data Generation:**
- **Python 3** with realistic clinical data
- **Faker** for generating HIPAA-compliant test data
- **REST client** for API integration

**Infrastructure:**
- **Docker Compose** for local development
- **Alpine Linux** for lightweight containers
- **ZSH** with enhanced terminal experience

## HIPAA Compliance Features

- **Anonymized Patient IDs**: Format `PT12AB34CD` (no real identifiers)
- **Medical Validation**: Realistic ranges for vitals, labs, and adverse events
- **Audit Trails**: Complete message tracking through the pipeline
- **Secure Transmission**: IBM MQ with persistent message delivery
- **Data Retention**: 7-year retention policy for regulatory compliance

## Monitoring & Observability

- **Health Checks**: `/api/clinical/health` endpoint
- **Metrics**: Processing statistics and success rates
- **Logging**: Structured logs for debugging and compliance
- **Message Tracking**: Unique message IDs through entire pipeline

```bash
# Access monitoring dashboards
Grafana:    http://localhost:3000
Prometheus: http://localhost:9090
Kibana:     http://localhost:5601
```

## Interview Demo Flow

This platform demonstrates several key concepts:

1. **Microservices Architecture**: Loosely coupled services with clear boundaries
2. **Message-Driven Design**: Asynchronous processing with IBM MQ
3. **Domain Modeling**: Healthcare entities with proper validation
4. **Container Development**: Complete environment without local installations
5. **Production Readiness**: Monitoring, logging, and error handling

### Demo Script
```bash
# Terminal 1: Start gateway
java -jar applications/clinical-data-gateway/target/clinical-data-gateway-1.0.0.jar

# Terminal 2: Generate data  
python operations/scripts/demo/clinical_data_generator.py --verbose

# Terminal 3: Monitor
curl -s http://localhost:8080/api/clinical/stats | jq
```

## API Documentation

### POST /api/clinical/data
Receives clinical trial data from healthcare sites.

**Example Payload:**
```json
{
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-09-08T14:30:45.123456",
  "study_phase": "Phase II",
  "site_id": "SITE001",
  "vital_signs": {
    "patient_id": "PT12AB34CD",
    "systolic_bp": 128,
    "diastolic_bp": 82,
    "heart_rate": 74,
    "temperature_celsius": 37.1
  }
}
```

## Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

🏥