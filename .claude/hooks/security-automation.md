# Security Automation Hooks

## Pre-commit Security Checks
```bash
# Secrets scanning
# Hook: pre-commit
gitleaks detect --source . --verbose
truffleHog --regex --entropy=False .

# Dependency vulnerability check
# Hook: on package.json/requirements.txt changes
npm audit --audit-level moderate
safety check -r requirements.txt

# Container security scanning
# Hook: on Dockerfile changes
hadolint Dockerfile
trivy config .
```

## CI/CD Security Integration
```bash
# SAST scanning in pipeline
# Hook: on code push
sonar-scanner -Dsonar.projectKey=myapp
semgrep --config=auto .

# Container image scanning
# Hook: after Docker build
trivy image myapp:latest --exit-code 1

# Infrastructure security scanning
# Hook: on Terraform changes
tfsec --soft-fail
checkov -f main.tf
```

## Runtime Security Monitoring
```bash
# Security monitoring alerts
# Hook: on security events
curl -X POST security_webhook -d "Security alert: $event"

# Automated incident response
# Hook: on critical vulnerabilities
kubectl scale deployment/vulnerable-app --replicas=0
argocd app sync security-patches
```

## Compliance Automation
```bash
# OWASP compliance checking
# Hook: weekly scheduled
zap-baseline.py -t https://myapp.com

# Security policy validation
# Hook: on policy changes
opa test policies/
conftest verify --policy policies/ k8s/

# Audit log analysis
# Hook: daily
kubectl logs audit-webhook | grep SECURITY
```

## Security Documentation Updates
- Auto-update security README on policy changes
- Generate security reports after scans
- Update threat model documentation
- Maintain security compliance matrix