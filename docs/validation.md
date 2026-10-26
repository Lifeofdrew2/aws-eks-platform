# Validation

What has been checked, how, and what has **not** been checked yet.

## Offline checks (no AWS account needed)

| Check | Tool | Result |
|---|---|---|
| App unit tests (6) | pytest | ✅ pass |
| Python lint | ruff | ✅ pass |
| Dockerfile lint | hadolint 2.15 | ✅ pass |
| Terraform formatting | `fmt -check` | ✅ pass |
| Terraform validate against the real VPC v6, EKS v21, Pod Identity v2 modules and AWS v6 provider | `validate` | ✅ "The configuration is valid." |
| Kubernetes manifests (9 objects) against 1.33 schemas | kustomize + kubeconform `-strict` | ✅ 9/9 valid |
| Security scan – Kubernetes | Checkov | 93 passed, 3 accepted ([security.md](security.md)) |
| Security scan – Terraform | Checkov | 8 passed, 5 accepted ([security.md](security.md)) |
| GitHub Actions workflow | actionlint | ✅ pass |

Reproduce: `make test lint validate`.

## Live deployment checklist

Run after `terraform apply` + `./scripts/deploy.sh`, and save the output or
screenshots in `docs/evidence/` — this is the strongest proof for reviewers.

- [ ] `kubectl get nodes -L topology.kubernetes.io/zone` shows nodes in 3 AZs
- [ ] `kubectl -n demo get pods -o wide` shows one pod per AZ
- [ ] `curl http://<alb-hostname>/api/orders` returns the order list
- [ ] Rolling update with a new tag completes with zero failed requests
      (run `while true; do curl -s -o /dev/null -w "%{http_code}\n" http://<alb>/healthz; done` during the rollout)
- [ ] Deleting a pod: replacement is Ready within ~30s, ALB never returns 5xx
- [ ] Draining one node: PDB keeps ≥ 2 pods available
- [ ] `kubectl -n demo get hpa` shows CPU metrics (metrics-server working)
- [ ] ECR console shows the image with scan results
- [ ] `./scripts/teardown.sh` leaves no load balancers, NAT gateways or EIPs behind
