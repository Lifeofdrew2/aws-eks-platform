#!/usr/bin/env bash
# Run every offline check for this repository (no AWS account needed).
# Requires: python3, terraform, kustomize, kubeconform, hadolint, actionlint, checkov
# Usage: ./scripts/verify.sh | tee docs/evidence/offline-validation.txt
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TF="${TF:-terraform}"
failures=0

step() { echo; echo "=== $1"; }
run() { "$@"; local rc=$?; [[ $rc -eq 0 ]] && echo "--> PASS" || { echo "--> FAIL (exit $rc)"; failures=$((failures + 1)); }; }

echo "verify.sh - aws-eks-platform"
echo "date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"

step "App: lint (ruff) and unit tests (pytest)"
run bash -c "cd app && ruff check . && python3 -m pytest -q -p no:cacheprovider --disable-warnings"

step "Dockerfile lint (hadolint)"
run hadolint app/Dockerfile

step "Terraform: fmt"
run "$TF" fmt -check -recursive terraform

step "Terraform: init + validate"
if [[ -n "${TF_VALIDATE_CMD:-}" ]]; then
  run $TF_VALIDATE_CMD terraform
else
  run bash -c "$TF -chdir=terraform init -backend=false -input=false >/dev/null && $TF -chdir=terraform validate"
fi

step "Kubernetes manifests (kustomize + kubeconform, K8s 1.33)"
run bash -c "kustomize build kubernetes | kubeconform -strict -summary -kubernetes-version 1.33.0 -"

step "Security scan: Kubernetes (checkov, informational)"
checkov -d kubernetes --framework kubernetes --compact --quiet 2>&1 | grep -E 'Passed checks|Check:' || true

step "Security scan: Terraform (checkov, informational)"
checkov -d terraform --framework terraform --compact --quiet 2>&1 | grep -E 'Passed checks|Check:' || true

step "GitHub Actions workflows (actionlint)"
run actionlint .github/workflows/*.yml

step "Shell script syntax"
run bash -n scripts/deploy.sh scripts/teardown.sh legacy/user-data.sh

echo
[[ $failures -eq 0 ]] && echo "RESULT: all checks passed" || echo "RESULT: $failures check(s) failed"
exit "$failures"
