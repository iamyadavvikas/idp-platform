# {{name}}

{{description}}

## Overview

This is a production-ready Go microservice built with IDP Platform standards. It includes:

- **GitOps**: Flux CD with Kustomize
- **Progressive Delivery**: Flagger canary deployments with Prometheus analysis
- **Observability**: Prometheus metrics, Grafana dashboards, Loki logging
- **Security**: Workload Identity, Network Policies, least-privilege RBAC
- **Infrastructure**: Terraform for Azure resources (AKS, Key Vault, PostgreSQL)
- **CI/CD**: GitHub Actions with linting, testing, SBOM, signing

## Quick Start

### Prerequisites

- Go 1.22+
- Docker
- kubectl
- flux CLI
- Azure CLI

### Local Development

```bash
# Run locally
go run app/main.go

# Build Docker image
docker build -t {{name}}:local ./app

# Run with Docker
docker run -p 8080:8080 -e ERROR_RATE=0.01 {{name}}:local

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/api
curl http://localhost:8080/status
curl http://localhost:8080/metrics
```

### Kubernetes Deployment

```bash
# Deploy to dev cluster
kubectl apply -k helm/{{name}}

# Check deployment status
kubectl get pods -n {{name}}
kubectl get canary -n {{name}}

# Trigger canary promotion
kubectl -n {{name}} patch canary {{name}} --type merge -p '{"spec":{"analysis":{"threshold":0}}}'
```

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Liveness probe |
| `GET /ready` | Readiness probe |
| `GET /api` | Main API endpoint (returns 200 or 500 based on ERROR_RATE) |
| `GET /status` | JSON status with metrics |
| `GET /metrics` | Prometheus metrics |
| `POST /setenv` | Set environment variables (ERROR_RATE, VERSION, FAIL_HEALTH) |

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `ERROR_RATE` | `0.01` | Probability of returning 500 (0.0-1.0) |
| `VERSION` | `1.0.0` | Version string for metrics |
| `FAIL_HEALTH` | `false` | When true, /health returns 503 |
| `PORT` | `8080` | HTTP listen port |

## Architecture

```
+-----------------+     +-----------------+     +-----------------+
|   Client        |---->|  Ingress        |---->|  Service        |
+-----------------+     +-----------------+     +------+----------+
                                                  |
                        +-----------------+     +--v----------+
                        | Prometheus      |<--->|  Deployment |
                        | (metrics)       |     |  (canary)   |
                        +-----------------+     +-------------+
```

## Canary Deployment

The service uses Flagger for progressive delivery:

1. **10%** traffic -> 30s analysis
2. **25%** traffic -> 30s analysis  
3. **50%** traffic -> 30s analysis
4. **75%** traffic -> 30s analysis
5. **100%** traffic -> promoted

At each step, Prometheus queries check:
- Request success rate >= 99%
- Request duration P99 <= 500ms

If thresholds breached -> automatic rollback.

## Terraform Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Creates:
- Azure PostgreSQL Flexible Server
- Key Vault secrets
- Private DNS zones
- Network policies

## Observability

### Grafana Dashboards
- Service Overview: Request rate, latency, error rate
- Canary Progress: Traffic weights, analysis status
- Resource Usage: CPU, memory, replicas

### Alerts
- `HighErrorRate`: >5% errors for 2m (warning)
- `CriticalErrorRate`: >15% errors for 30s (critical, triggers rollback)
- `InstanceDown`: Service unreachable for 1m

### Logs
Structured JSON logs shipped to Loki via promtail.

## Security

- **Workload Identity**: Azure AD pod identity via OIDC federation
- **Network Policies**: Default deny, explicit allow for monitoring/ingress
- **RBAC**: Least-privilege service accounts
- **Secrets**: Azure Key Vault -> External Secrets Operator -> K8s Secrets

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `go fmt ./... && go vet ./... && go test ./...`
4. Open a PR

## License

MIT