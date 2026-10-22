# Azure Deployment Guide

## Overview

This guide walks through deploying the IDP Platform to Azure AKS with all components: networking, AKS, Key Vault, monitoring, GitOps (Flux), progressive delivery (Flagger), and Backstage.

## Prerequisites

### Required Tools
```bash
# Azure CLI
az version
# Should be 2.50+

# Terraform
terraform version
# Should be 1.7+

# kubectl
kubectl version --client
# Should be 1.28+

# flux CLI
flux version
# Should be 2.2+

# kubelogin
kubelogin --version
# Should be 0.1.0+

# GitHub CLI
gh auth status
```

### Azure Permissions
You need **Owner** or **Contributor + User Access Administrator** on the subscription to:
- Create resource groups
- Create service principals for GitHub OIDC
- Assign RBAC roles
- Create Key Vaults with purge protection

### GitHub Repository
- Fork or create `yourorg/idp-platform`
- Enable GitHub Actions
- Create environments: `dev`, `stage`, `prod` with protection rules
- Add secrets (see below)

## GitHub Secrets Configuration

### Repository Secrets
| Secret | Description | Example |
|--------|-------------|---------|
| `AZURE_CLIENT_ID` | Service principal client ID for GitHub OIDC | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `ACR_USERNAME` | ACR admin username | `yourregistry` |
| `ACR_PASSWORD` | ACR admin password | `xxxxxxxx` |
| `INFRACOST_API_KEY` | Infracost API key | `ico-xxxxxxxxxxxxxxxx` |
| `GITHUB_TOKEN` | GitHub PAT with repo/admin:repo_hook/workflow | `ghp_xxxxxxxxxxxxxxxxxxxx` |

### Environment Secrets (dev/stage/prod)
| Secret | Description |
|--------|-------------|
| `ARGOCD_TOKEN` | ArgoCD API token (if using ArgoCD) |
| `GRAFANA_API_KEY` | Grafana API key for Backstage |
| `LOKI_API_KEY` | Loki API key for Backstage |

## Step 1: Create Azure Service Principal for GitHub OIDC

```bash
# Create service principal
az ad sp create-for-rbac --name "github-oidc-idp-platform" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

# Output will be JSON - save for GitHub secret AZURE_CREDENTIALS (legacy)
# For OIDC, we need the client ID and tenant ID

# Get the app ID
APP_ID=$(az ad sp show --id <sp-name> --query appId -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
```

### Configure GitHub OIDC Federation

```bash
# Create federated identity credential for GitHub Actions
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:yourorg/idp-platform:ref:refs/heads/main",
    "description": "GitHub Actions main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For PRs
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:yourorg/idp-platform:pull_request",
    "description": "GitHub Actions pull requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Step 2: Deploy Global State Backend

```bash
cd terraform/global/azure

# Initialize
terraform init

# Review plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Note outputs:
# - storage_account_name
# - container_name
# - cosmosdb_account_name
# - cosmosdb_database_name
# - cosmosdb_container_name
```

## Step 3: Deploy Dev Environment

```bash
cd ../../environments/azure/dev

# Initialize with backend config from global outputs
terraform init \
  -backend-config="resource_group_name=idp-terraform-state-rg" \
  -backend-config="storage_account_name=<storage_account_name>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=azure/dev/terraform.tfstate"

# Review plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

### Verify Dev Deployment

```bash
# Get AKS credentials
az aks get-credentials --resource-group dev-aks-rg --name idp-dev --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Check Key Vault
az keyvault list -g dev-kv-rg

# Check DNS
az network dns zone list -g dev-dns-rg
```

## Step 4: Bootstrap Flux

```bash
# Install flux CLI if not done
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux to dev cluster
flux bootstrap github \
  --owner=yourorg \
  --repository=idp-platform \
  --branch=main \
  --path=flux-system/clusters/dev \
  --personal \
  --token-auth \
  --components-extra=image-reflector-controller,image-automation-controller

# Verify
flux get all -n flux-system
```

## Step 5: Verify Platform Components

### Monitoring Stack
```bash
# Check Prometheus
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Check Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Admin password: changeme (change in production!)

# Check Loki
kubectl get pods -n monitoring -l app=loki
```

### External Secrets
```bash
# Check ClusterSecretStore
kubectl get clustersecretstore

# Check ExternalSecrets
kubectl get externalsecrets -A

# Verify secret sync
kubectl get secret demo-app-secrets -n demo-app -o yaml
```

### Ingress NGINX
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Get public IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### Flagger
```bash
# Check Flagger
kubectl get pods -n flux-system -l app=flagger

# Check canary CRD
kubectl get canary -A
```

## Step 6: Deploy Demo App

```bash
# The demo app should be deployed via Flux automatically
# Check status
kubectl get pods -n demo-app
kubectl get canary -n demo-app

# Test the app
kubectl port-forward -n demo-app svc/demo-app 8080:80
curl http://localhost:8080/health
curl http://localhost:8080/api
curl http://localhost:8080/status
curl http://localhost:8080/metrics
```

## Step 7: Test Progressive Delivery

```bash
# Watch canary status
watch kubectl get canary -n demo-app

# Trigger bad version (15% error rate)
curl -X POST http://localhost:8080/setenv?key=ERROR_RATE&val=0.15
curl -X POST http://localhost:8080/setenv?key=VERSION&val=2.0.0-bad

# Fire requests
for i in {1..50}; do curl -s http://localhost:8080/api > /dev/null; done

# Watch auto-rollback
watch kubectl get canary -n demo-app
```

## Step 8: Deploy Stage/Prod

```bash
# Stage
cd terraform/environments/azure/stage
terraform init -reconfigure \
  -backend-config="key=azure/stage/terraform.tfstate"
terraform apply -auto-approve

# Get credentials
az aks get-credentials -g stage-aks-rg -n idp-stage --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Bootstrap Flux for stage
flux bootstrap github \
  --owner=yourorg \
  --repository=idp-platform \
  --branch=main \
  --path=flux-system/clusters/stage \
  --personal \
  --token-auth

# Prod
cd ../prod
terraform init -reconfigure \
  -backend-config="key=azure/prod/terraform.tfstate"
terraform apply -auto-approve

# Get credentials
az aks get-credentials -g prod-aks-rg -n idp-prod --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Bootstrap Flux for prod
flux bootstrap github \
  --owner=yourorg \
  --repository=idp-platform \
  --branch=main \
  --path=flux-system/clusters/prod \
  --personal \
  --token-auth
```

## Step 9: Deploy Backstage (Prod)

```bash
# Get prod cluster credentials
az aks get-credentials -g prod-aks-rg -n idp-prod --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Create namespace
kubectl create namespace backstage

# Create secrets for Backstage
kubectl create secret generic backstage-secrets -n backstage \
  --from-literal=GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID \
  --from-literal=GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=GRAFANA_API_KEY=$GRAFANA_API_KEY \
  --from-literal=LOKI_API_KEY=$LOKI_API_KEY

# Deploy Backstage
cd backstage
helm upgrade --install backstage ./helm \
  -n backstage \
  -f helm/values.yaml \
  --set backstage.auth.providers.github.development.clientId=$GITHUB_CLIENT_ID \
  --set backstage.auth.providers.github.development.clientSecret=$GITHUB_CLIENT_SECRET \
  --set postgresql.postgresqlPassword=$POSTGRES_PASSWORD

# Verify
kubectl get pods -n backstage
kubectl port-forward -n backstage svc/backstage 7007:7007
```

## Step 10: Configure Backstage Integrations

### GitHub App for Backstage
1. Create GitHub App in your organization
2. Configure permissions:
   - Repository: Contents (Read), Metadata (Read), Actions (Read)
   - Organization: Members (Read)
3. Generate private key
4. Add to Backstage secrets

### Azure AD App for Backstage
1. Create App Registration in Azure AD
2. Add redirect URI: `https://backstage.idp.example.com/api/auth/github/handler/frame`
3. Add API permissions: User.Read, openid, profile, email
4. Generate client secret
5. Add to Backstage secrets

## Validation Checklist

- [ ] All 3 environments deployed (dev, stage, prod)
- [ ] Flux bootstrapped on all clusters
- [ ] Monitoring stack healthy (Prometheus, Grafana, Loki)
- [ ] External Secrets syncing from Key Vault
- [ ] Ingress NGINX with public IP (prod)
- [ ] Flagger canary working (demo app)
- [ ] Auto-rollback triggers at 15% error rate
- [ ] Backstage accessible and showing catalog
- [ ] GitHub Actions CI/CD passing
- [ ] Infracost commenting on PRs

## Troubleshooting

### Flux not syncing
```bash
# Check GitRepository
flux get sources git -n flux-system

# Check Kustomization
flux get kustomizations -n flux-system

# Force reconcile
flux reconcile kustomization <name> -n flux-system --with-source
```

### AKS private cluster access
```bash
# Use Azure CLI to get credentials
az aks get-credentials -g <rg> -n <cluster> --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

# Or use private endpoint
az network private-endpoint create ...
```

### Workload Identity issues
```bash
# Check federated identity credential
az identity show -g <rg> -n <identity> --query "federatedIdentityCredentials"

# Verify service account annotation
kubectl get sa <name> -n <ns> -o yaml
```

### Key Vault access denied
```bash
# Check access policies
az keyvault show -n <kv> --query "properties.accessPolicies"

# Or RBAC
az role assignment list --assignee <object-id> --scope <kv-id>
```

## Cost Optimization

### Dev/Stage: Spot Instances
- User node pools use spot instances (~70% savings)
- System node pools always on-demand
- Configure max price for spot

### Prod: Reserved Instances
- 1-year or 3-year reserved for system pools
- Consider Azure Savings Plan

### Monitoring
- Log Analytics: Set daily cap
- Prometheus: 15d retention, 10GB limit
- Loki: 7d retention

### Cleanup
```bash
# Destroy dev (keep prod)
cd terraform/environments/azure/dev
terraform destroy -auto-approve

# Destroy all
cd terraform/global/azure
terraform destroy -auto-approve
```

## Security Hardening (Production)

- [ ] Enable Azure Policy for AKS
- [ ] Enable Microsoft Defender for Containers
- [ ] Configure Private Clusters (no public API server)
- [ ] Enable Azure Disk Encryption (CMK)
- [ ] Configure Key Vault purge protection
- [ ] Enable ACR geo-replication
- [ ] Configure Front Door / Application Gateway WAF
- [ ] Enable Azure AD Conditional Access
- [ ] Configure Network Watcher flow logs
- [ ] Enable Azure Security Center recommendations