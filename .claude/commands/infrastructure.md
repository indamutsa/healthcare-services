# Infrastructure Commands

## Docker Operations
```bash
# Build and run containers
docker build -t app:latest .
docker run -p 3000:3000 app:latest
docker-compose up -d

# Multi-stage builds
docker build --target production -t app:prod .

# Container management
docker ps
docker logs <container_id>
docker exec -it <container_id> /bin/bash

# Registry operations
docker tag app:latest registry/app:latest
docker push registry/app:latest
```

## Kubernetes Operations
```bash
# Cluster management
kubectl get nodes
kubectl get pods --all-namespaces
kubectl describe pod <pod_name>

# Deployment operations
kubectl apply -f k8s/
kubectl rollout status deployment/app
kubectl rollout undo deployment/app

# Service and ingress
kubectl get svc
kubectl get ingress
kubectl port-forward svc/app 3000:80

# Debugging
kubectl logs -f deployment/app
kubectl exec -it pod/app-xxx -- /bin/bash
```

## Terraform Operations
```bash
# Infrastructure lifecycle
terraform init
terraform plan
terraform apply
terraform destroy

# Workspace management
terraform workspace new staging
terraform workspace select production

# State management
terraform state list
terraform state show <resource>
terraform import <resource> <id>

# Module operations
terraform get -update
terraform validate
```