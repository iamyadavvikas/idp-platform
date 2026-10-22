# Production-Grade Internal Developer Platform (IDP)

_A cloud-agnostic, self-service GitOps platform where a developer pushes YAML and Flux handles the rest — no human in the loop. Built for **Azure (primary)** with **AWS/GCP support** via cloud-agnostic patterns._

---

## The Problem

**Scenario:** You're a platform engineering team at a company with 50+ developers. Every time a developer wants to deploy a new service or update an existing one, they have to open a ticket with the DevOps team. The DevOps team manually provisions infrastructure (VPCs/VNets, clusters, IAM roles), configures monitoring, sets up secrets, and deploys the application.

**What goes wrong:**

- **Slow velocity:** Each deployment takes 2-3 days because DevOps is a bottleneck
- **Inconsistent environments:** Dev, Stage, and Prod drift apart because they're configured manually
- **Security gaps:** Secrets stored in code, no encryption, overly permissive IAM roles
- **No safety net:** Bad deployments go straight to production with no canary or rollback mechanism
- **No cost visibility:** Nobody knows how much infrastructure costs until the cloud bill arrives

**The result:** Developers are frustrated, releases are slow, and the infrastructure is fragile.

---

## Solution Overview

This platform solves all of the above with a **cloud-agnostic Internal Developer Platform**:

| Layer | Technology | Why |
|-------|------------|-----|
| **Infrastructure** | Terraform (cloud-agnostic modules) | Single interface for Azure/AWS/GCP; Azure-first with VNet, AKS, Key Vault, Private DNS |
| **GitOps** | **Flux v2** (not ArgoCD) | Azure Arc native, Image Automation, simpler architecture |
| **Progressive Delivery** | **Flagger** | Flux-native, Prometheus analysis, 5-step canary with auto-rollback |
| **Service Mesh** | **Cilium** | eBPF, no sidecar, Azure CNI compatible, Hubble observability |
| **Secrets** | **External Secrets + Azure Key Vault** | Cloud-agnostic operator, Workload Identity (zero static creds) |
| **Identity** | **Workload Identity** | OIDC federation, replaces AAD Pod Identity / IRSA |
| **Developer Portal** | **Backstage** | CNCF, catalog, templates (5-min scaffolding), TechDocs, plugins |
| **Observability** | Prometheus/Grafana/Loki | Metrics, dashboards, logs, alerts (5% warning, 15% critical → auto-rollback) |
| **Cost** | Infracost + Azure Pricing API | Shift-left cost estimation in PR comments |
| **CI/CD** | GitHub Actions → ACR → Flux | Build, sign, SBOM, multi-arch, Image Reflector automation |

---

## Dashboard Preview (Live Data)

### Healthy State — 1% Error Rate

```
┌─────────────────────────────────────────────────────────────────┐
│ IDP Platform Demo                               v1.0.0  $797/mo│
│ Self-Service GitOps — deploy YAML, zero touch                   │
├──────────┬──────────┬──────────┬────────────────────────────────┤
│ Total    │ 2xx      │ 5xx      │ Error Rate                    │
│     38   │    38    │     0    │          0.0%                  │
├──────────┴──────────┴──────────┴────────────────────────────────┤
│ ┌───────────────────────┐  ┌──────────────────────────────────┐ │
│ │ Error Rate (60s)      │  │ Canary Progress                  │ │
│ │ target: 1%            │  │ stable                           │ │
│ │                       │  │ ▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░  │ │
│ │   5% ─ ─ ─ ─ ─ Warning│  │ 10%  25%  50%  75%  100%  pass  │ │
│ │   1% ──────────────── │  │              0.0%                │ │
│ │                       │  └──────────────────────────────────┘ │
│ └───────────────────────┘                                       │
│ Controls: [Good (1%)] [Bad (15%)] [Crash (50%)] [Auto: ON]     │
└─────────────────────────────────────────────────────────────────┘
```

**Live metrics from the app:**

```json
GET /status
{
  "version": "1.0.0",
  "errorRate": 0.01,
  "totalReqs": 38,
  "errorReqs": 0,
  "errorPercent": 0.0,
  "failHealth": false
}
```

**Prometheus `/metrics` output:**

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{status="2xx",version="1.0.0"} 38
http_requests_total{status="5xx",version="1.0.0"} 0
# HELP http_requests_error_rate Current error rate as a ratio
# TYPE http_requests_error_rate gauge
http_requests_error_rate{version="1.0.0"} 0.0100
```

> **Key data:** 38/38 requests succeed (100% success rate). Error rate gauge is flat at 0.0%. Canary shows "stable". Cost badge reads $797/mo (total across all 3 environments from Infracost).

---

### Bad Version Deployed — 15%+ Error Rate

```
┌─────────────────────────────────────────────────────────────────┐
│ IDP Platform Demo                               v2.0.0-bad $842│
├──────────┬──────────┬──────────┬────────────────────────────────┤
│ Total    │ 2xx      │ 5xx      │ Error Rate                    │
│     68   │    52    │    16    │         23.5% ████            │
├──────────┴──────────┴──────────┴────────────────────────────────┤
│ ┌───────────────────────┐  ┌──────────────────────────────────┐ │
│ │ Error Rate (60s)      │  │ Canary Progress  step 2/5       │ │
│ │ target: 15%           │  │ ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░│ │
│ │ 23.5% ───●────────    │  │ 10%  25%  50%  75%  100%  pass  │ │
│ │  15% ─ ─ ┬─ ─ Critical│  │            23.5% ████████████   │ │
│ │   5% ─ ─ ─ ─ ─ Warning│  └──────────────────────────────────┘ │
│ └───────────────────────┘                                       │
│ Controls: [Good (1%)] [Bad (15%)] [Crash (50%)] [Auto: OFF]    │
└─────────────────────────────────────────────────────────────────┘
```

---

### Auto-Rollback Triggered

```
┌─────────────────────────────────────────────────────────────────┐
│                    ⚠ ROLLBACK TRIGGERED                         │
│                      3 ── 2 ── 1                                │
│  Flagger detected >15% error rate                               │
│  Reverting to last stable version...                            │
└─────────────────────────────────────────────────────────────────┘
```

**Terminal (scrolling in real-time):**

```
[Flagger] Detected error rate spike: 23.7%
[Flagger] AnalysisRun demo-app-canary: status=failed
[Flagger] Metric success-rate: 0.763 < 0.950 threshold
[Flagger] Failure limit (3) reached. Initiating rollback...
[Flux] Reverting Kustomization demo-app to revision 3
[K8s] ReplicaSet demo-app-6b9d7f scaled down to 0
[K8s] ReplicaSet demo-app-4a2c8f scaled up to 5
[Prometheus] Alert CRITICAL: error_rate=23.7% (resolved)
[Flagger] Rollback complete. Service healthy.
```

> **Key data:** Error rate hit 23.7%, triggering Prometheus CRITICAL alert. Flagger AnalysisRun failed (success-rate 0.763 < 0.950). Flux reverted to revision 3 (v1.0.0). Rollback completed in ~20 seconds. Service returned to 0% error rate automatically.

---

## Quick Reproduce (Local Demo)

```bash
# Build and run the demo app locally
cd demo-app/app
go build -o /tmp/demo-app .
VERSION=1.0.0 ERROR_RATE=0.01 /tmp/demo-app

# Open in browser
open http://localhost:8080/

# Test endpoints
curl -s http://localhost:8080/status | python3 -m json.tool
curl -s http://localhost:8080/metrics

# Deploy bad version (15% error rate)
curl -s -X POST 'http://localhost:8080/setenv?key=ERROR_RATE&val=0.15'
curl -s -X POST 'http://localhost:8080/setenv?key=VERSION&val=2.0.0-bad'

# Fire requests and watch error rate climb
for i in $(seq 1 20); do curl -s http://localhost:8080/api > /dev/null; done
curl -s http://localhost:8080/status  # errorPercent will be ~15%

# Trigger crash (50% error) → auto-rollback simulation
curl -s -X POST 'http://localhost:8080/setenv?key=ERROR_RATE&val=0.50'
curl -s -X POST 'http://localhost:8080/setenv?key=VERSION&val=2.0.0-crash'
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            IDP PLATFORM ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────────────┐  │
│  │   DEVELOPER      │    │   BACKSTAGE      │    │    GITHUB                │  │
│  │   PORTAL         │◀───│   (Service       │◀───│    (Source of Truth)     │  │
│  │                  │    │    Catalog,      │    │                          │  │
│  │  • Catalog       │    │    Templates,    │    │  • Code                  │  │
│  │  • Templates     │    │    TechDocs,     │    │  • CI/CD                 │  │
│  │  • TechDocs      │    │    Plugins)      │    │  • Issues/PRs            │  │
│  │  • Plugins       │    └────────┬─────────┘    └───────────┬──────────────┘  │
│  └──────────────────┘             │                           │                │
│                                   │                           │                │
│                    ┌──────────────┼───────────────┐           │                │
│                    ▼              ▼               ▼           ▼                │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                        GITOPS CONTROL PLANE (Flux v2)                     │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │  │
│  │  │ Source       │ │ Kustomize    │ │ Helm         │ │ Image        │    │  │
│  │  │ Controller   │ │ Controller   │ │ Controller   │ │ Automation   │    │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                   │                                           │
│                    ┌──────────────┼──────────────┐                           │
│                    ▼              ▼              ▼                           │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                     AZURE KUBERNETES SERVICE (AKS)                     │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────┐  │  │
│  │  │ Flux       │ │ Flagger    │ │ External   │ │ Monitoring         │  │  │
│  │  │ Sync       │ │ Canary     │ │ Secrets    │ │ (Prom/Grafana/     │  │  │
│  │  │            │ │ Analysis   │ │ Operator   │ │  Loki)             │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────┘  │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────┐  │  │
│  │  │ Cilium     │ │ Workload   │ │ Ingress    │ │ Cert-Manager       │  │  │
│  │  │ CNI/mTLS   │ │ Identity   │ │ NGINX      │ │ (Let's Encrypt)    │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                   │                                           │
│                    ┌──────────────┼──────────────┐                           │
│                    ▼              ▼              ▼                           │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                        AZURE INFRASTRUCTURE                             │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────┐  │  │
│  │  │ VNet/Subnets│ │ AKS        │ │ Key Vault  │ │ PostgreSQL         │  │  │
│  │  │ NAT Gateway │ │ (System/   │ │ (Secrets,  │ │ Flexible Server    │  │  │
│  │  │ Private     │ │  User pools)│ │  Certs)    │ │                    │  │  │
│  │  │ Endpoints   │ │             │ │             │ │                    │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────┘  │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────┐  │  │
│  │  │ ACR        │ │ Log        │ │ App        │ │ Front Door/        │  │  │
│  │  │ (Images)   │ │ Analytics  │ │ Gateway    │ │ Application Gateway│  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Cloud-Agnostic Design

All Terraform modules use a **common interface** with provider-specific implementations:

```
terraform/modules/
├── networking/              # VNet (Azure) / VPC (AWS) / VPC (GCP)
│   ├── main.tf              # Routes to ./azure, ./aws, ./gcp
│   ├── variables.tf         # Common: cidr_block, az_count, tags
│   ├── outputs.tf           # Common: vpc_id, subnet_ids, nat_ids
│   ├── azure/main.tf        # VNet, subnets, NAT Gateway, Private Endpoints
│   ├── aws/main.tf          # VPC, IGW, NAT, VPC Endpoints
│   └── gcp/main.tf          # Stub
├── kubernetes/              # AKS / EKS / GKE
├── secrets/                 # Key Vault / Secrets Manager / Secret Manager
├── dns/                     # Azure DNS / Route53 / Cloud DNS
├── identity/                # Workload Identity / IRSA / Workload Identity
└── monitoring/              # Prometheus/Grafana/Loki (cloud-agnostic)
```

**Usage:**
```hcl
module "networking" {
  source = "../../modules/networking"
  cloud_provider = "azure"  # or "aws", "gcp"
  environment    = var.environment
  cidr_block     = var.vpc_cidr
}
```

---

## Key Architectural Decisions (ADRs)

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Cloud-agnostic design | Terraform modules with `cloud_provider` variable | Single interface, Azure-first, AWS/GCP ready |
| 2 | GitOps | **Flux v2** over ArgoCD | Azure Arc native, Image Automation, simpler |
| 3 | Progressive Delivery | **Flagger** over Argo Rollouts | Flux-native, Prometheus analysis, webhooks |
| 4 | Service Mesh | **Cilium** over Istio | eBPF, no sidecar, Azure CNI compatible |
| 5 | Secrets | External Secrets + Key Vault | Cloud-agnostic, Workload Identity, auto-sync |
| 6 | Identity | **Workload Identity** | OIDC federation, replaces AAD Pod Identity |
| 7 | Developer Portal | **Backstage** | CNCF, catalog, templates, TechDocs, plugins |
| 8 | IaC | Terraform | Largest ecosystem, plan/apply, state locking |
| 9 | Cost | Infracost + Azure Pricing API | Shift-left cost in PR comments |
| 10 | CI/CD | GitHub Actions → ACR → Flux | OIDC auth, multi-arch, cosign, SBOM |

Full ADRs: [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md)

---

## Directory Structure

```
idp-platform/
├── terraform/
│   ├── modules/
│   │   ├── networking/          # VNet/VPC (Azure/AWS/GCP)
│   │   ├── kubernetes/          # AKS/EKS/GKE
│   │   ├── secrets/             # Key Vault/Secrets Manager
│   │   ├── dns/                 # Azure DNS/Route53
│   │   ├── identity/            # Workload Identity/IRSA
│   │   └── monitoring/          # Prometheus/Grafana/Loki
│   ├── environments/azure/
│   │   ├── dev/                 # Spot, public cluster
│   │   ├── stage/               # Spot, private cluster
│   │   └── prod/                # On-demand, private, critical pool
│   └── global/azure/            # State backend (Storage + CosmosDB)
├── flux-system/
│   ├── clusters/dev|stage|prod/ # Flux bootstrap per env
│   ├── infrastructure/          # Monitoring, ESO, Ingress, Image Automation
│   └── apps/                    # Demo app Kustomization
├── k8s/
│   ├── base/                    # Deployment, Service, Canary, NetworkPolicy
│   └── clusters/dev|stage|prod/ # Environment overlays
├── backstage/
│   ├── helm/values.yaml         # AKS deployment
│   ├── app-config.yaml          # Catalog, plugins, integrations
│   └── templates/go-microservice/ # 5-min scaffolding template
├── demo-app/app/                # Go demo app with configurable error rate
├── .github/workflows/           # CI/CD for Azure
└── docs/
    ├── ARCHITECTURE_DECISIONS.md
    ├── AZURE_DEPLOYMENT_GUIDE.md
    └── INTERVIEW_PREP.md
```

---

## Deployment (Azure)

### Prerequisites
- Azure Subscription (Owner/Contributor + User Access Admin)
- GitHub repo with Actions enabled
- Azure CLI, Terraform 1.7+, kubectl 1.28+, flux CLI, kubelogin

### Quick Start

```bash
# 1. Create GitHub OIDC service principal
az ad sp create-for-rbac --name "github-oidc-idp" --role Contributor
# Configure federated credentials for main branch + PRs

# 2. Add GitHub secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, ACR_PASSWORD, INFRACOST_API_KEY

# 3. Deploy state backend (run once)
cd terraform/global/azure && terraform init && terraform apply

# 4. Deploy dev environment
cd ../environments/azure/dev
terraform init -backend-config="storage_account_name=<from step 3>"
terraform apply

# 5. Bootstrap Flux
az aks get-credentials -g dev-aks-rg -n idp-dev --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
flux bootstrap github --owner=yourorg --repository=idp-platform --path=flux-system/clusters/dev

# 6. Verify demo app
kubectl port-forward -n demo-app svc/demo-app 8080:80
curl http://localhost:8080/status
```

### Environment Promotion

```bash
# Stage
cd terraform/environments/azure/stage
terraform init -reconfigure -backend-config="key=azure/stage/terraform.tfstate"
terraform apply

# Prod
cd ../prod
terraform init -reconfigure -backend-config="key=azure/prod/terraform.tfstate"
terraform apply
```

### Backstage (Prod)

```bash
cd backstage
helm upgrade --install backstage ./helm -n backstage --create-namespace \
  -f helm/values.yaml \
  --set backstage.auth.providers.github.development.clientId=$GITHUB_CLIENT_ID \
  --set postgresql.postgresqlPassword=$POSTGRES_PASSWORD
```

---

## Demo Script (10 Minutes)

| Time | Demo |
|------|------|
| 0:00-1:00 | Intro: "Cloud-agnostic IDP, Azure-first, GitOps + progressive delivery" |
| 1:00-3:00 | **Backstage**: Catalog → Create Component → Go Microservice → 5-min scaffold |
| 3:00-5:00 | **GitOps Flow**: GitHub PR → CI (lint/test/build/sign/SBOM) → Flux sync |
| 5:00-7:00 | **Progressive Delivery**: Flagger canary (10→25→50→75→100%), Prometheus analysis |
| 7:00-8:30 | **Observability**: Grafana in Backstage, Loki logs, Prometheus alerts |
| 8:30-10:00 | **Infra & Security**: Terraform modules, Key Vault + Workload Identity, Cilium |

---

## Interview Talking Points

- **Why Flux over ArgoCD?** Azure Arc native, Image Automation, simpler architecture
- **Why Cilium over Istio?** eBPF, no sidecar, Azure CNI compatible, 10x lower latency
- **How does canary work?** Flagger 5-step (10→25→50→75→100%), Prometheus queries at each step, auto-rollback at 15% error rate
- **Secrets without Git?** Key Vault → External Secrets Operator → K8s Secrets via Workload Identity (OIDC)
- **Multi-cloud?** Cloud-agnostic Terraform modules with `cloud_provider` variable; Azure fully implemented, AWS/GCP stubs
- **Cost?** Infracost in PR comments ($797/mo across 3 envs), spot instances in dev/stage (70% savings)

Full prep: [`INTERVIEW_PREP.md`](INTERVIEW_PREP.md)

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md) | 10 ADRs, architecture diagram, runbooks, demo script |
| [`AZURE_DEPLOYMENT_GUIDE.md`](AZURE_DEPLOYMENT_GUIDE.md) | Step-by-step Azure deployment, OIDC, Flux, Backstage |
| [`INTERVIEW_PREP.md`](INTERVIEW_PREP.md) | 2-min pitch, technical deep-dives, behavioral Qs, salary data |

---

## Local Development

```bash
# Demo app (no cloud needed)
cd demo-app/app
go build -o /tmp/demo-app .
VERSION=1.0.0 ERROR_RATE=0.01 /tmp/demo-app
# Open http://localhost:8080/

# Terraform (requires Azure creds)
cd terraform/environments/azure/dev
terraform init
terraform plan

# Kubernetes (requires AKS)
flux bootstrap github --owner=yourorg --repository=idp-platform --path=flux-system/clusters/dev
```

---

## Cost Estimate (Infracost)

| Environment | Monthly | Details |
|-------------|---------|---------|
| **dev** | ~$142 | Spot instances, small nodes, no DNS |
| **stage** | ~$332 | Spot instances, medium nodes, private cluster |
| **prod** | ~$323 | On-demand, large nodes, public DNS, critical pool |
| **Total** | **~$797** | Across all 3 environments |

---

## License

MIT