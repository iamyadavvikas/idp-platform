# Architecture Decision Records (ADRs)

## ADR-001: Cloud-Agnostic Platform Design

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need to support Azure (primary), AWS, and GCP for enterprise customers  
**Decision**: Implement cloud-agnostic Terraform modules with provider-specific implementations  
**Consequences**: 
- Single interface for all clouds
- Azure-first implementation with AWS/GCP stubs
- Clear migration path between clouds

## ADR-002: GitOps with Flux over ArgoCD

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need GitOps controller for Azure AKS  
**Decision**: Use Flux v2 instead of ArgoCD  
**Rationale**:
- CNCF Graduated (ArgoCD is Incubating)
- Native Azure Arc integration
- Flux Image Automation replaces manual image updates
- Simpler architecture (no Redis, no separate Application controller)
- Kustomize/Helm controllers built-in

## ADR-003: Progressive Delivery with Flagger

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need canary deployments with automated rollback  
**Decision**: Use Flagger instead of Argo Rollouts  
**Rationale**:
- Native Flux integration
- Works with Istio/Linkerd/Cilium/NGINX
- Prometheus-based analysis
- Webhook support for load testing
- Simpler CRDs than Argo Rollouts

## ADR-004: Service Mesh with Cilium

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need mTLS, traffic management, network policies  
**Decision**: Use Cilium over Istio/Linkerd  
**Rationale**:
- eBPF-based, no sidecar overhead
- Native Azure CNI integration
- NetworkPolicy enforcement at kernel level
- Hubble observability built-in
- Lower resource consumption
- Simpler operations

## ADR-005: Secrets Management with External Secrets + Azure Key Vault

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need secure secrets management without storing in Git  
**Decision**: External Secrets Operator with Azure Key Vault  
**Rationale**:
- Cloud-agnostic operator (supports AWS/GCP too)
- Workload Identity for authentication (no static creds)
- Automatic sync from Key Vault to K8s Secrets
- Supports rotation and versioning
- Integrates with Flagger for secret updates

## ADR-006: Workload Identity for Pod Authentication

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need secure pod-to-cloud authentication  
**Decision**: Azure Workload Identity (OIDC federation)  
**Rationale**:
- Replaces deprecated AAD Pod Identity
- No node-level daemonset required
- Works with any OIDC-compatible identity provider
- Standard Kubernetes service account annotations
- Supports cross-cloud federation

## ADR-007: Developer Portal with Backstage

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need self-service platform for developers  
**Decision**: Backstage (CNCF) with custom templates  
**Rationale**:
- CNCF incubating project, strong community
- Software Catalog for service discovery
- Software Templates for scaffolding
- TechDocs for documentation
- Plugin ecosystem (ArgoCD, K8s, GitHub Actions, Grafana, Loki)

## ADR-008: Infrastructure as Code with Terraform

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need reproducible, version-controlled infrastructure  
**Decision**: Terraform with cloud-agnostic modules  
**Rationale**:
- Largest provider ecosystem
- Mature state management with locking
- Plan/apply workflow prevents accidents
- Strong enterprise adoption
- Supports all three target clouds

## ADR-009: Cost Estimation with Infracost

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need shift-left cost visibility  
**Decision**: Infracost in CI/CD pipelines  
**Rationale**:
- Supports Azure, AWS, GCP
- PR comments with cost breakdown
- Integrates with Terraform plan
- Policy-as-code for cost guardrails

## ADR-010: CI/CD with GitHub Actions + ACR + Flux

**Status**: Accepted  
**Date**: 2024-01-15  
**Context**: Need end-to-end pipeline from code to cluster  
**Decision**: GitHub Actions → ACR → Flux Image Automation  
**Rationale**:
- Native Azure integration (OIDC auth)
- ACR for multi-arch images with geo-replication
- Flux Image Reflector/Automation for GitOps
- Cosign signing + SBOM generation
- Dependabot for dependency updates

---

# Platform Architecture

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

# Deployment Guide

## Prerequisites

- Azure Subscription with Owner/Contributor access
- Azure CLI (`az`) v2.50+
- Terraform v1.7+
- kubectl v1.28+
- flux CLI v2.2+
- kubelogin
- GitHub CLI (`gh`) with repo access
- GitHub Personal Access Token with `repo`, `admin:repo_hook`, `workflow` scopes

## Quick Start (Dev Environment)

```bash
# 1. Login to Azure
az login
az account set --subscription <SUBSCRIPTION_ID>

# 2. Create state storage (run once)
cd terraform/global/azure
terraform init
terraform apply -auto-approve

# 3. Deploy dev environment
cd ../../environments/azure/dev
terraform init \
  -backend-config="resource_group_name=idp-terraform-state-rg" \
  -backend-config="storage_account_name=idpterraformstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=azure/dev/terraform.tfstate"
terraform apply -auto-approve

# 4. Get AKS credentials
az aks get-credentials --resource-group dev-aks-rg --name idp-dev --overwrite-existing

# 5. Bootstrap Flux
flux bootstrap github \
  --owner=yourorg \
  --repository=idp-platform \
  --branch=main \
  --path=flux-system/clusters/dev \
  --personal \
  --token-auth
```

## Environment Promotion

```bash
# Stage
cd terraform/environments/azure/stage
terraform init -reconfigure \
  -backend-config="key=azure/stage/terraform.tfstate"
terraform apply -auto-approve

# Prod
cd terraform/environments/azure/prod
terraform init -reconfigure \
  -backend-config="key=azure/prod/terraform.tfstate"
terraform apply -auto-approve
```

## Post-Deployment Verification

```bash
# Check Flux status
flux get all -n flux-system

# Check canary status
kubectl get canary -A

# Check monitoring
kubectl get pods -n monitoring

# Check secrets sync
kubectl get externalsecrets -A
```

## Secrets Configuration

```bash
# Add secrets to Key Vault
az keyvault secret set --vault-name <kv-name> --name demo-app-db-password --value "secure-password"
az keyvault secret set --vault-name <kv-name> --name demo-app-api-key --value "secure-api-key"

# Verify External Secrets sync
kubectl get externalsecret -n demo-app
kubectl get secret demo-app-secrets -n demo-app -o yaml
```

## Backstage Deployment

```bash
# Deploy Backstage to prod cluster
cd backstage
helm upgrade --install backstage ./helm \
  -n backstage --create-namespace \
  -f helm/values.yaml \
  --set backstage.auth.providers.github.development.clientId=$GITHUB_CLIENT_ID \
  --set backstage.auth.providers.github.development.clientSecret=$GITHUB_CLIENT_SECRET \
  --set postgresql.postgresqlPassword=$POSTGRES_PASSWORD
```

---

# Runbooks

## Runbook: AKS Cluster Unhealthy

**Symptoms**: Nodes NotReady, pods stuck in Pending, API server errors  
**Severity**: Critical  
**Owner**: Platform Team  

### Diagnosis
```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check AKS health
az aks show -g <rg> -n <cluster> --query "provisioningState"
```

### Resolution
1. **Node NotReady**: Check Azure VM status, restart if needed
2. **CNI issues**: Restart Azure CNI pods `kubectl delete pods -n kube-system -l k8s-app=azure-cni`
3. **API server down**: Check Azure status page, consider manual upgrade
4. **Etcd issues**: Restore from backup (Velero)

---

## Runbook: Canary Rollback Stuck

**Symptoms**: Flagger canary stuck in progress, not rolling back  
**Severity**: High  
**Owner**: Platform Team  

### Diagnosis
```bash
# Check canary status
kubectl get canary -n <namespace> -o yaml

# Check Flagger logs
kubectl logs -n flux-system deploy/flagger

# Check Prometheus metrics
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090
```

### Resolution
1. **Manual rollback**: `kubectl -n <ns> patch canary <name> --type merge -p '{"spec":{"analysis":{"threshold":0}}'`
2. **Force sync**: `flux reconcile kustomization <name> -n flux-system --with-source`
3. **Check analysis template**: Verify Prometheus query returns data

---

## Runbook: External Secrets Not Syncing

**Symptoms**: ExternalSecret status "SecretSynced: False"  
**Severity**: High  
**Owner**: Platform Team  

### Diagnosis
```bash
# Check ExternalSecret status
kubectl get externalsecret -n <namespace> -o yaml

# Check ClusterSecretStore
kubectl get clustersecretstore azure-keyvault -o yaml

# Check Workload Identity
kubectl get sa external-secrets -n external-secrets -o yaml
```

### Resolution
1. **Workload Identity**: Verify federated identity credential matches service account
2. **Key Vault access**: Check Key Vault access policies / RBAC
3. **Network**: Verify private endpoint and DNS resolution
4. **Restart operator**: `kubectl rollout restart deploy/external-secrets -n external-secrets`

---

## Runbook: Flux Sync Failing

**Symptoms**: Kustomization stuck in Progressing or Failed  
**Severity**: High  
**Owner**: Platform Team  

### Diagnosis
```bash
# Check Kustomization status
flux get kustomizations -n flux-system

# Check GitRepository
flux get sources git -n flux-system

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Resolution
1. **Git auth**: Verify deploy key / PAT has access
2. **Kustomize build**: Run locally `kustomize build <path>`
3. **Force reconcile**: `flux reconcile kustomization <name> -n flux-system --with-source`
4. **Delete and recreate**: `flux delete kustomization <name> -n flux-system` then re-bootstrap

---

## Runbook: High Error Rate Alert

**Symptoms**: Prometheus alert firing for error rate > 5% / 15%  
**Severity**: Warning / Critical  
**Owner**: Service Owner + Platform Team  

### Diagnosis
```bash
# Check service status
kubectl get pods -n <namespace>

# Check recent deployments
kubectl rollout history deployment/<name> -n <namespace>

# Check logs
kubectl logs -n <namespace> -l app=<name> --tail=100
```

### Resolution
1. **Auto-rollback**: Flagger should auto-rollback at 15%
2. **Manual rollback**: `kubectl rollout undo deployment/<name> -n <namespace>`
3. **Investigate**: Check application logs, dependencies, resource limits
4. **Scale up**: Increase replicas if resource exhaustion

---

# Interview Talking Points

## "Walk me through your platform architecture"

**Answer**: "I built a cloud-agnostic Internal Developer Platform with Azure as the primary target. The platform has three layers:

1. **Infrastructure Layer**: Terraform modules for VNet, AKS, Key Vault, PostgreSQL, DNS - all with cloud-agnostic interfaces and Azure implementations
2. **GitOps Control Plane**: Flux v2 for GitOps (chosen over ArgoCD for Azure Arc integration), Flagger for progressive delivery with Prometheus-based canary analysis
3. **Developer Experience**: Backstage for service catalog, templates, and embedded observability

The demo shows a Go microservice that deploys via Flux, canaries with Flagger (10→25→50→75→100%), and auto-rolls back when error rate exceeds 15%."

## "Why Flux over ArgoCD?"

**Answer**: "Three reasons for Azure:
1. **Azure Arc native integration** - Flux is the recommended GitOps controller for Azure Arc-enabled Kubernetes
2. **Simpler architecture** - No Redis, no separate Application controller, built-in Kustomize/Helm controllers
3. **Image Automation** - Flux Image Reflector/Automation replaces the manual image update pattern needed with ArgoCD"

## "How does your canary deployment work?"

**Answer**: "Flagger creates a primary and canary deployment. Traffic shifts through 5 steps (10%, 25%, 50%, 75%, 100%) with 30s analysis windows. At each step, Flagger queries Prometheus for:
- Request success rate (must be ≥99%)
- Request duration P99 (must be ≤500ms)

If either threshold breaches, Flagger automatically rolls back. The demo simulates this with a configurable error rate endpoint."

## "How do you handle secrets?"

**Answer**: "Never in Git. Azure Key Vault stores secrets, External Secrets Operator syncs them to Kubernetes Secrets using Workload Identity (OIDC federation). Each service gets a dedicated service account with a federated identity credential scoped to its Key Vault secrets. Rotation in Key Vault propagates to pods within 30s."

## "What's your multi-cloud strategy?"

**Answer**: "Cloud-agnostic Terraform modules with a `cloud_provider` variable that selects the implementation (azure/aws/gcp). The module interface (inputs/outputs) is identical across providers. Currently Azure is fully implemented with AWS/GCP stubs. This allows deploying the same platform to any cloud with minimal changes."

## "How do you handle cost?"

**Answer**: "Infracost runs on every Terraform PR, posting a cost breakdown as a comment. Dev/stage use spot instances (~70% savings), prod uses on-demand. The platform shows estimated monthly cost per environment in Backstage. Future: Azure Cost Management integration for real-time cost tracking."

## "What would you improve?"

**Answer**: 
1. **Policy Engine**: Add Kyverno for admission control (resource limits, security contexts, image signatures)
2. **Disaster Recovery**: Velero for backup/restore with cross-region DR
3. **Service Mesh**: Full Cilium mTLS with L7 policies
4. **Cost Guardrails**: Azure Budgets + automated alerts + quota enforcement
5. **Compliance**: CIS benchmarks, Falco runtime security, audit logging
6. **Backstage**: Scorecards for service maturity, plugin for Azure Cost Management"

---

# Demo Script (10 minutes)

## 0:00-1:00 Introduction
"Here's a cloud-agnostic IDP platform with Azure as primary target. It demonstrates GitOps, progressive delivery, and developer self-service."

## 1:00-3:00 Backstage Demo
1. Open Backstage: `https://backstage.idp.example.com`
2. Show Catalog: Services, ownership, dependencies
3. Create new service: "Create Component" → "Go Microservice" → Fill form → Creates repo + scaffolds code
4. Show TechDocs: Auto-generated from repo

## 3:00-5:00 GitOps Flow
1. Show GitHub repo with new service
2. Show GitHub Actions: CI (lint, test, build, sign, SBOM) → CD (Flux sync)
3. Show Flux in cluster: `flux get kustomizations`

## 5:00-7:00 Progressive Delivery
1. Show Flagger canary: `kubectl get canary`
2. Explain 5-step canary with Prometheus analysis
3. Demo: Change error rate → watch canary progress → auto-rollback

## 7:00-8:30 Observability
1. Grafana: Embedded in Backstage service page
2. Loki logs: Filter by trace ID
3. Prometheus alerts: Warning at 5%, critical at 15%

## 8:30-10:00 Infrastructure & Security
1. Terraform: Show module structure, cloud-agnostic design
2. Key Vault + External Secrets + Workload Identity
3. Network Policies, Cilium mTLS
4. Cost: Infracost PR comment

---

# Quick Reference Commands

```bash
# Terraform
terraform init -reconfigure -backend-config="key=azure/dev/terraform.tfstate"
terraform plan -out=tfplan
terraform apply tfplan

# Flux
flux bootstrap github --owner=yourorg --repository=idp-platform --path=flux-system/clusters/dev
flux get kustomizations -n flux-system
flux reconcile kustomization <name> -n flux-system --with-source

# AKS
az aks get-credentials -g <rg> -n <cluster> --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Canary
kubectl get canary -n <namespace>
kubectl -n <ns> patch canary <name> --type merge -p '{"spec":{"analysis":{"threshold":0}}'

# Secrets
az keyvault secret set --vault-name <kv> --name <secret> --value <value>
kubectl get externalsecret -n <ns>
kubectl get secret <name> -n <ns> -o yaml

# Monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007
```