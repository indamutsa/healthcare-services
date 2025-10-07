# Project Context

## Tech Stack
- **Languages**: Python, TypeScript, JavaScript, Java, Node.js, HTML, CSS, Bash
- **Frontend**: React, Next.js, TailwindCSS
- **Backend**: FastAPI (Python), Express/NestJS (Node.js), SpringBoot (Java)
- **Infrastructure**: Docker, Kubernetes, Terraform, ArgoCD, Argo rollouts, Istio/Linkerd Mesh
- **Databases**: PostgreSQL, MongoDB, Redis, elasticsearch
- **CI/CD**: GitHub Actions, ArgoCD, Jenkins
- **Monitoring**: Prometheus, Grafana, ELK Stack
- **Testing**: Jest, React Testing Library, PyTest, Supertest
- **Security**: BurpSuite, Metasploit, DevSecOps practices
- **Tools**: Git, npm/yarn, pip, poetry, kubectl, helm

## Development Standards
- Prefer functional components and hooks in React
- Use TypeScript strict mode
- Follow PEP 8 for Python
- Use ESLint + Prettier for JS/TS
- TailwindCSS for styling
- Type safety is priority

## Common Commands
- `npm run dev` - Start Next.js dev server
- `npm run build` - Build Next.js app
- `npm run lint` - Run ESLint
- `npm run typecheck` - TypeScript check
- `uvicorn main:app --reload` - Start FastAPI dev server
- `npm start` - Start Node.js server
- `pytest` - Run Python tests
- `npm test` - Run Node.js tests
- `docker build -t app .` - Build Docker image
- `kubectl apply -f k8s/` - Deploy to Kubernetes
- `terraform plan` - Plan infrastructure changes

## Project Structure
- Frontend typically in `/` or `/frontend`
- Backend typically in `/api` or `/backend`
- Shared types in `/types` or `/shared`
- Infrastructure in `/infra` or `/terraform`
- Kubernetes manifests in `/k8s` or `/manifests`
- Security configs in `/security`

## Code Style
- Minimal explanations needed
- Focus on implementation
- Prefer existing patterns
- Security-first approach




                                                                                          
 