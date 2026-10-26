#!/usr/bin/env bash
# Build the image, push it to ECR and deploy it to the EKS cluster.
# Usage: ./scripts/deploy.sh [image-tag]   (defaults to the current git SHA)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-$(git -C "$ROOT" rev-parse --short HEAD)}"

REGION="$(terraform -chdir="$ROOT/terraform" output -raw region)"
CLUSTER="$(terraform -chdir="$ROOT/terraform" output -raw cluster_name)"
REPO_URL="$(terraform -chdir="$ROOT/terraform" output -json ecr_repository_urls | jq -r '."demo-api"')"
REGISTRY="${REPO_URL%%/*}"

echo "==> Logging in to ECR ($REGISTRY)"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> Building and pushing $REPO_URL:$TAG"
docker build --platform linux/amd64 --build-arg APP_VERSION="$TAG" -t "$REPO_URL:$TAG" "$ROOT/app"
docker push "$REPO_URL:$TAG"

echo "==> Deploying to $CLUSTER"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null
WORK="$(mktemp -d)"
cp -r "$ROOT/kubernetes/." "$WORK/"
(cd "$WORK" && kustomize edit set image "demo-api=$REPO_URL:$TAG")
kubectl apply -k "$WORK"

echo "==> Waiting for rollout"
if ! kubectl -n demo rollout status deployment/demo-api --timeout=5m; then
  echo "Rollout failed - rolling back to the previous ReplicaSet" >&2
  kubectl -n demo rollout undo deployment/demo-api
  exit 1
fi

echo "==> Pods by Availability Zone"
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase'
kubectl get nodes -L topology.kubernetes.io/zone

echo "==> Load balancer address (may take 2-3 minutes to become reachable)"
kubectl -n demo get ingress demo-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
