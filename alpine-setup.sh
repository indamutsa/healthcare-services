#!/bin/bash

# Alpine Container Setup Script for Healthcare Clinical Trials Platform
# This script installs all necessary tools in an Alpine Linux container

set -e  # Exit on any error

echo "🏔️  Setting up Alpine Container for Healthcare Clinical Trials Platform"
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Update package manager
print_info "Updating Alpine package manager..."
apk update
apk upgrade
print_status "Package manager updated"

# Install basic tools
print_info "Installing basic development tools..."
apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    tar \
    gzip \
    ca-certificates \
    openssl
print_status "Basic tools installed"

# Install Java 17 (OpenJDK)
print_info "Installing Java 17 (OpenJDK)..."
apk add --no-cache openjdk17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc

# Verify Java installation
java -version
print_status "Java 17 installed successfully"

# Install Maven
print_info "Installing Apache Maven..."
apk add --no-cache maven

# Verify Maven installation
mvn -version
print_status "Maven installed successfully"

# Install Python 3 and pip
print_info "Installing Python 3 and development tools..."
apk add --no-cache \
    python3 \
    python3-dev \
    py3-pip \
    py3-virtualenv \
    build-base \
    linux-headers
    
# Create symlinks for easier usage
ln -sf python3 /usr/bin/python
ln -sf pip3 /usr/bin/pip

# Verify Python installation
python --version
pip --version
print_status "Python 3 installed successfully"

# Install Docker (for running IBM MQ container)
print_info "Installing Docker..."
apk add --no-cache docker docker-compose

# Note: Docker daemon needs to be started separately
print_warning "Docker installed. You may need to start the Docker daemon with: 'service docker start'"

# Install Node.js (useful for potential frontend work)
print_info "Installing Node.js..."
apk add --no-cache nodejs npm
node --version
npm --version
print_status "Node.js installed successfully"

# Install useful development utilities
print_info "Installing additional development utilities..."
apk add --no-cache \
    jq \
    httpie \
    netcat-openbsd \
    telnet \
    bind-tools \
    iputils
print_status "Development utilities installed"

# Create workspace directories
print_info "Setting up workspace directories..."
mkdir -p ~/workspace/healthcare-platform
mkdir -p ~/workspace/logs
mkdir -p ~/workspace/data
print_status "Workspace directories created"

# Install Python dependencies for the clinical data generator
print_info "Setting up Python virtual environment..."
cd ~/workspace/healthcare-platform

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install Python packages
pip install --upgrade pip
pip install \
    requests==2.31.0 \
    pydantic==2.5.0 \
    python-dateutil==2.8.2 \
    python-dotenv==1.0.0 \
    pytest==7.4.3 \
    faker==20.1.0

print_status "Python virtual environment and packages installed"

# Set up environment variables
print_info "Setting up environment variables..."
cat > ~/.bashrc << 'EOF'
# Java Configuration
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# Maven Configuration
export M2_HOME=/usr/share/maven
export PATH=$M2_HOME/bin:$PATH

# Python Configuration
export PYTHONPATH=$PYTHONPATH:~/workspace/healthcare-platform

# Healthcare Platform Configuration
export HEALTHCARE_WORKSPACE=~/workspace/healthcare-platform
export MQ_QMGR_NAME=CLINICAL_QM
export MQ_HOST=localhost
export MQ_PORT=1414
export MQ_APP_USER=clinical_app
export MQ_APP_PASSWORD=clinical123

# Aliases for convenience
alias ll='ls -la'
alias la='ls -la'
alias python='python3'
alias pip='pip3'
alias healthcare-logs='tail -f ~/workspace/logs/*.log'
alias healthcare-workspace='cd ~/workspace/healthcare-platform'

# Function to activate Python virtual environment
activate-healthcare() {
    cd ~/workspace/healthcare-platform
    source venv/bin/activate
    echo "Healthcare Platform Python environment activated"
}

# Welcome message
echo "🏥 Healthcare Clinical Trials Platform - Alpine Container Ready!"
echo "Run 'activate-healthcare' to start working"
EOF

# Source the bashrc to apply changes
source ~/.bashrc
print_status "Environment variables configured"

# Create a quick start script
print_info "Creating quick start scripts..."
cat > ~/start-healthcare-platform.sh << 'EOF'
#!/bin/bash

echo "🏥 Starting Healthcare Clinical Trials Platform"
echo "=============================================="

# Start Docker daemon if not running
if ! pgrep dockerd > /dev/null; then
    echo "Starting Docker daemon..."
    service docker start
    sleep 5
fi

# Navigate to workspace
cd ~/workspace/healthcare-platform

# Activate Python environment
source venv/bin/activate

echo ""
echo "✅ Healthcare Platform environment ready!"
echo ""
echo "Available commands:"
echo "  mvn clean package                    # Build Spring Boot applications"
echo "  python clinical_data_generator.py   # Generate clinical data"
echo "  docker-compose up -d                # Start IBM MQ"
echo "  curl http://localhost:8080/api/clinical/health  # Test gateway"
echo ""
echo "Useful aliases:"
echo "  healthcare-workspace    # Navigate to platform directory"
echo "  healthcare-logs        # View application logs"
echo ""
EOF

chmod +x ~/start-healthcare-platform.sh
print_status "Quick start script created"

# Create IBM MQ Docker setup script
print_info "Creating IBM MQ setup script..."
cat > ~/setup-ibm-mq.sh << 'EOF'
#!/bin/bash

echo "🔄 Setting up IBM MQ in Docker container"
echo "========================================"

# Start Docker if not running
service docker start
sleep 3

# Pull IBM MQ Docker image
echo "Pulling IBM MQ Docker image..."
docker pull icr.io/ibm-messaging/mq:latest

# Create directory for MQ data
mkdir -p ~/workspace/healthcare-platform/mq-data

# Run IBM MQ container
echo "Starting IBM MQ container..."
docker run -d \
  --name healthcare-mq \
  -p 1414:1414 \
  -p 9443:9443 \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=CLINICAL_QM \
  -e MQ_APP_PASSWORD=clinical123 \
  -e MQ_ADMIN_PASSWORD=admin123 \
  -v ~/workspace/healthcare-platform/mq-data:/mnt/mqm \
  icr.io/ibm-messaging/mq:latest

# Wait for MQ to start
echo "Waiting for IBM MQ to start..."
sleep 30

# Check if MQ is running
if docker ps | grep healthcare-mq > /dev/null; then
    echo "✅ IBM MQ is running successfully!"
    echo ""
    echo "Connection details:"
    echo "  Queue Manager: CLINICAL_QM"
    echo "  Host: localhost"
    echo "  Port: 1414"
    echo "  Channel: DEV.APP.SVRCONN"
    echo "  User: app"
    echo "  Password: clinical123"
    echo ""
    echo "Web Console: https://localhost:9443/ibmmq/console"
    echo "  Admin User: admin"
    echo "  Admin Password: admin123"
else
    echo "❌ Failed to start IBM MQ. Check Docker logs:"
    docker logs healthcare-mq
fi
EOF

chmod +x ~/setup-ibm-mq.sh
print_status "IBM MQ setup script created"

# Display summary
echo ""
echo "🎉 Alpine Container Setup Complete!"
echo "==================================="
echo ""
echo "Installed tools:"
echo "  ✅ Java 17 (OpenJDK)"
echo "  ✅ Apache Maven"
echo "  ✅ Python 3 with virtual environment"
echo "  ✅ Docker and Docker Compose"
echo "  ✅ Node.js and npm"
echo "  ✅ Development utilities (git, curl, jq, etc.)"
echo ""
echo "Quick start commands:"
echo "  ~/start-healthcare-platform.sh    # Activate development environment"
echo "  ~/setup-ibm-mq.sh                # Set up IBM MQ in Docker"
echo ""
echo "Next steps:"
echo "  1. Run: source ~/.bashrc"
echo "  2. Run: ~/start-healthcare-platform.sh"
echo "  3. Clone/copy your healthcare platform code"
echo "  4. Run: ~/setup-ibm-mq.sh"
echo "  5. Build and run your applications"
echo ""
print_status "Setup completed successfully!"