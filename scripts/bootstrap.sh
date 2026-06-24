#!/usr/bin/env bash
set -euo pipefail

echo "=== IDP Platform Bootstrap ==="

AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${1:-dev}"

echo "Bootstrapping $ENVIRONMENT environment in $AWS_REGION"

# 1. Create Terraform state bucket and DynamoDB table
echo ">>> Bootstrapping Terraform backend..."
cd "$(dirname "$0")/../terraform/global"
terraform init
terraform apply -auto-approve

# 2. Deploy infrastructure
echo ">>> Deploying $ENVIRONMENT infrastructure..."
cd "$(dirname "$0")/../terraform/environments/$ENVIRONMENT"
terraform init -reconfigure
terraform apply -auto-approve

# 3. Get kubeconfig
echo ">>> Configuring kubectl..."
CLUSTER_NAME="$(terraform output -raw eks_cluster_name)"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# 4. Install ArgoCD
echo ">>> Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true \
  --wait

echo ">>> ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# 5. Apply ArgoCD app configs
echo ">>> Applying ArgoCD project and application manifests..."
kubectl apply -f "$(dirname "$0")/../argocd/projects/"
kubectl apply -f "$(dirname "$0")/../argocd/applications/$ENVIRONMENT.yaml"

# 6. Install monitoring stack
echo ">>> Installing Prometheus Stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$(dirname "$0")/../monitoring/prometheus/prometheus-values.yaml" \
  --wait

# 7. Install Loki
echo ">>> Installing Loki..."
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values "$(dirname "$0")/../monitoring/loki/loki-values.yaml" \
  --wait

# 8. Install External Secrets
echo ">>> Installing External Secrets..."
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --values "$(dirname "$0")/../external-secrets/external-secrets-values.yaml" \
  --wait

echo "=== Bootstrap Complete ==="
echo ""
echo "ArgoCD URL:    http://$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Grafana URL:   https://grafana.idp.example.com"
echo "Demo App URL:  https://demo-app.idp.example.com"
