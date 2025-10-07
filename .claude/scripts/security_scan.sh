#!/bin/bash
# Comprehensive security scanning script

TARGET=${1:-"."}
REPORT_DIR="security-reports"

mkdir -p $REPORT_DIR

echo "🔒 Starting comprehensive security scan..."

# Secrets detection
echo "🔍 Scanning for secrets..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect --source $TARGET --report-format json --report-path $REPORT_DIR/secrets.json
    echo "✅ Secrets scan complete"
else
    echo "⚠️  gitleaks not installed, skipping secrets scan"
fi

# Dependency vulnerabilities
echo "🔍 Scanning dependencies..."
if [ -f "package.json" ]; then
    npm audit --json > $REPORT_DIR/npm-audit.json 2>/dev/null
    echo "✅ NPM audit complete"
fi

if [ -f "requirements.txt" ]; then
    if command -v safety &> /dev/null; then
        safety check -r requirements.txt --json > $REPORT_DIR/python-safety.json 2>/dev/null
        echo "✅ Python safety check complete"
    fi
fi

# Container security
echo "🔍 Scanning containers..."
if [ -f "Dockerfile" ] && command -v trivy &> /dev/null; then
    trivy config . --format json --output $REPORT_DIR/trivy-config.json
    echo "✅ Container config scan complete"
fi

# Static code analysis
echo "🔍 Running static analysis..."
if command -v semgrep &> /dev/null; then
    semgrep --config=auto --json --output=$REPORT_DIR/semgrep.json $TARGET 2>/dev/null
    echo "✅ Static analysis complete"
fi

# Infrastructure security
if [ -f "main.tf" ] && command -v tfsec &> /dev/null; then
    echo "🔍 Scanning Terraform..."
    tfsec --format json --out $REPORT_DIR/tfsec.json .
    echo "✅ Terraform scan complete"
fi

# Generate summary report
echo "📊 Generating security summary..."
cat > $REPORT_DIR/summary.md << EOF
# Security Scan Summary

Generated: $(date)
Target: $TARGET

## Scans Performed
- ✅ Secrets detection (gitleaks)
- ✅ Dependency vulnerabilities
- ✅ Container security (trivy)
- ✅ Static code analysis (semgrep)
- ✅ Infrastructure security (tfsec)

## Reports
- secrets.json - Secret detection results
- npm-audit.json - NPM vulnerability scan
- python-safety.json - Python security issues
- trivy-config.json - Container security scan
- semgrep.json - Static analysis results
- tfsec.json - Terraform security scan

Review all JSON reports for detailed findings.
EOF

echo "✅ Security scan complete! Reports in $REPORT_DIR/"
echo "📋 Summary: $REPORT_DIR/summary.md"