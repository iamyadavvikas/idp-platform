#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=== Destroying IDP Platform: $ENVIRONMENT ==="
read -p "Are you sure? This is destructive! (type '$ENVIRONMENT' to confirm): " CONFIRM
if [[ "$CONFIRM" != "$ENVIRONMENT" ]]; then
  echo "Aborted."
  exit 1
fi

echo ">>> Destroying $ENVIRONMENT infrastructure..."
cd "$(dirname "$0")/../terraform/environments/$ENVIRONMENT"
terraform init -reconfigure
terraform destroy -auto-approve

echo "=== Destroy complete for $ENVIRONMENT ==="
