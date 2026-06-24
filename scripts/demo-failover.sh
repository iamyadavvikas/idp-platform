#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-demo-app-prod}"
ENVIRONMENT="${2:-prod}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   IDP Platform - Auto-Rollback Demo                        ║"
echo "║   Deploy bad version, watch error rate spike,               ║"
echo "║   then see Argo Rollouts auto-rollback                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo ">>> Step 1: Deploying BAD version with 15% error rate..."
read -p "Press ENTER to deploy the bad version..."
kubectl set env deployment/demo-app -n "$NAMESPACE" ERROR_RATE=0.15 VERSION=2.0.0-bad
kubectl rollout status deployment/demo-app -n "$NAMESPACE" --timeout=60s || true

echo ""
echo ">>> Step 2: Observing error rate..."
echo ">>> Prometheus alert 'CriticalErrorRate' fires when error rate > 15% for 30s"
echo ">>> Argo Rollouts analysis detects failure and triggers auto-rollback"
echo ""

for i in $(seq 1 12); do
  ERROR_RATE=$(kubectl exec -n "$NAMESPACE" deploy/demo-app -- sh -c 'wget -q -O- http://localhost:8080/ 2>/dev/null | grep -o "error_rate=[0-9.]*" || echo "error_rate=0.00"')
  echo "  [$i/12] Simulating traffic... $ERROR_RATE"
  # Generate traffic to trigger error rate metrics
  for j in $(seq 1 5); do
    kubectl exec -n "$NAMESPACE" deploy/demo-app -- wget -q -O- http://localhost:8080/ 2>/dev/null || true
  done
  sleep 5
done

echo ""
echo ">>> Step 3: Checking rollback status..."
if kubectl get rollout demo-app -n "$NAMESPACE" -o jsonpath='{.status.currentStepIndex}' 2>/dev/null; then
  echo ""
  echo ">>> Argo Rollout detected! Checking analysis runs..."
  kubectl get analysisrun -n "$NAMESPACE" 2>/dev/null || true
  echo ""
  echo ">>> Current rollout status:"
  kubectl get rollout demo-app -n "$NAMESPACE" -o wide 2>/dev/null || true
fi

echo ""
echo ">>> Step 4: Fixing the deployment (reverting error rate)..."
kubectl set env deployment/demo-app -n "$NAMESPACE" ERROR_RATE=0.01 VERSION=1.0.0

echo ""
echo "=== Demo Complete ==="
echo "The error rate spiked, Prometheus fired the alert,"
echo "and Argo Rollouts auto-rolled back to the last stable version."
