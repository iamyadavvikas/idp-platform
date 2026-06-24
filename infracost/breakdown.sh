#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"

echo "=== Infracost Breakdown: $ENV ==="

cd "$(dirname "$0")/../terraform/environments/$ENV"

terraform init -reconfigure
terraform plan -out=plan.tfplan

infracost breakdown \
  --path . \
  --terraform-plan-file plan.tfplan \
  --format table \
  --out-file "/tmp/infracost-$ENV.txt"

echo "Breakdown saved to /tmp/infracost-$ENV.txt"
cat "/tmp/infracost-$ENV.txt"
