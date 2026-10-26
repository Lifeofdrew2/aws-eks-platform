#!/usr/bin/env bash
# Destroy everything this repository created, in the right order.
# The Ingress must be deleted first so the AWS Load Balancer Controller can
# remove the ALB it created; otherwise the ALB and its security groups block
# VPC deletion.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Deleting Kubernetes workloads (removes the ALB)"
kubectl delete -k "$ROOT/kubernetes" --ignore-not-found --wait=true || true

echo "==> Waiting 60s for the load balancer to be deprovisioned"
sleep 60

echo "==> Destroying infrastructure"
terraform -chdir="$ROOT/terraform" destroy -auto-approve

echo "Done. Check the EC2 > Load Balancers and VPC consoles to confirm nothing is left running."
