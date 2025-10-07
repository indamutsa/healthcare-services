# GitOps ArgoCD Hooks

## Application Sync Automation
```bash
# Auto-sync on config changes
# Hook: on k8s/ directory changes
argocd app sync myapp --prune

# Validate manifests before commit
# Hook: pre-commit
kubectl apply --dry-run=client -f k8s/
helm template . --validate

# Security scanning before deployment
# Hook: pre-deployment
trivy config k8s/
```

## Environment Management
```bash
# Auto-promotion between environments
# Hook: after successful staging deployment
argocd app sync myapp-prod --revision HEAD

# Rollback on failure detection
# Hook: on deployment failure
argocd app rollback myapp

# Configuration drift detection
# Hook: scheduled
argocd app diff myapp
```

## Application Health Monitoring
```bash
# Health check automation
# Hook: post-deployment
argocd app wait myapp --health
argocd app get myapp --refresh

# Alert on sync failures
# Hook: on sync failure
curl -X POST webhook_url -d "ArgoCD sync failed for myapp"

# Automated testing after deployment
# Hook: post-sync
kubectl wait --for=condition=available deployment/myapp
npm run e2e:production
```

## GitOps Workflow Patterns
- Branch-based environments (main→prod, develop→staging)
- Pull-based deployment model
- Configuration as code
- Automated rollbacks on health check failure
- Security scanning in GitOps pipeline

## ArgoCD Application Configuration
- Auto-sync enabled for non-production
- Manual sync for production environments
- Prune and self-heal policies
- Resource tracking and diffing
- RBAC integration with Git permissions