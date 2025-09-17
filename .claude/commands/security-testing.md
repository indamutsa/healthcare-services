# Security Testing Commands

## Container Security Scanning
```bash
# Trivy vulnerability scanning
trivy image app:latest
trivy fs . --security-checks vuln,config

# Docker security best practices check
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  docker/docker-bench-security

# Hadolint Dockerfile linting
hadolint Dockerfile
```

## Web Application Security Testing
```bash
# OWASP ZAP automated scanning
zap-baseline.py -t http://localhost:3000

# Nuclei vulnerability scanner
nuclei -u http://localhost:3000 -t /path/to/templates

# SSL/TLS testing
testssl.sh --quiet localhost:443
```

## Dependency Vulnerability Scanning
```bash
# Node.js dependencies
npm audit
npm audit fix
snyk test

# Python dependencies
safety check
pip-audit

# General dependency scanning
dependency-check --project "MyApp" --scan .
```

## Code Security Analysis
```bash
# Static code analysis
sonar-scanner -Dsonar.projectKey=myapp

# Secrets detection
truffleHog --regex --entropy=False .
gitleaks detect --source .

# Security linting
bandit -r ./python-code/
semgrep --config=auto .
```

## Infrastructure Security
```bash
# Kubernetes security scanning
kube-bench
kube-hunter --remote <cluster_ip>

# Terraform security scanning
tfsec .
checkov -f main.tf

# Network security testing
nmap -sS -O target_ip
```

## BurpSuite Integration
```bash
# Start BurpSuite with project
burpsuite --project-file=project.burp

# Automated scanning via API
curl -X POST "http://localhost:1337/burp/scanner/scans/active" \
  -H "Content-Type: application/json" \
  -d '{"urls":["http://localhost:3000"]}'
```