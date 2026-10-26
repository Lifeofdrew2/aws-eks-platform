# Security

## Controls in place

| Area | Control |
|---|---|
| Network | Nodes and pods in private subnets only; VPC flow logs enabled |
| Network | Default-deny NetworkPolicy; app accepts only port 8080 from the VPC and may only call DNS |
| Cluster API | Public endpoint restricted to `api_allowed_cidrs`; private endpoint enabled for nodes |
| Cluster audit | `api`, `audit` and `authenticator` control-plane logs sent to CloudWatch |
| Secrets at rest | EKS secrets envelope-encrypted with a KMS key (module default); ECR encrypted with KMS |
| Identity | EKS access entries (no `aws-auth` ConfigMap); Pod Identity for the LB controller |
| Nodes | IMDSv2 required, hop limit 1; Amazon Linux 2023 AMI |
| Images | Immutable tags; scan on push; non-root user (UID 10001); multi-stage build |
| Pods | `restricted` Pod Security Standard enforced on the namespace; read-only root FS; all capabilities dropped; seccomp `RuntimeDefault`; no service account token mounted |

## Scanner results (Checkov)

Run with `checkov -d terraform` and `checkov -d kubernetes`. Results at the time of writing:

- Kubernetes: **93 passed, 3 failed**
- Terraform (root module): **8 passed, 5 failed** (all listed below)

### Accepted findings

| Check | Why it is accepted |
|---|---|
| CKV_K8S_14 / CKV_K8S_43 – image tag/digest | The base manifest uses a placeholder image name; `deploy.sh` (and the CI/CD repo) set the real ECR image with an immutable git-SHA tag at deploy time. |
| CKV_K8S_15 – `imagePullPolicy: Always` | Tags are immutable in ECR, so `IfNotPresent` is safe and avoids a registry call on every pod start. |
| CKV_TF_1 – module source by commit hash | Modules are pinned to a version range from the Terraform registry, and `.terraform.lock.hcl` pins providers. Commit-hash pinning is stricter and can be adopted if required by policy. |
| CKV_AWS_394 – AZ data source | The AZ list is sliced to a fixed count (`az_count`), so new AZs do not change the subnets. |

## Not included (would add for production)

- TLS on the ALB with an ACM certificate and HTTP→HTTPS redirect (annotations are in `kubernetes/ingress.yaml`, commented)
- AWS WAF on the ALB
- Private-only API endpoint reached through a VPN or bastion
- GuardDuty EKS protection and Security Hub
- Image signing and admission policy (e.g. Kyverno)
