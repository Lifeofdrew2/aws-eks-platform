# Legacy baseline: EC2-hosted application ("before")

This folder represents the **starting point** of the re-platforming: a typical
VM-based deployment that many teams run before moving to containers. It is a
simplified, synthetic example written for this demonstration.

## How the legacy setup worked

| Concern | Legacy (EC2) | Re-platformed (EKS) |
|---|---|---|
| Compute | Hand-launched EC2 instances, often in a single AZ | EKS managed node group (EC2) across 3 AZs |
| Packaging | `git pull` + `pip install` on the server | Immutable Docker image in Amazon ECR |
| Process manager | systemd unit (`demo-api.service`) | Kubernetes Deployment with probes |
| Deployments | SSH to each server, restart service | Rolling update, zero unavailable pods |
| Scaling | Manually add instances | HPA (pods) + node group min/max (nodes) |
| Load balancing | Classic/ALB with static targets | ALB created from Ingress, targets pod IPs |
| Config drift | Servers diverge over time | Declarative Terraform + manifests in Git |
| Recovery | Rebuild server by hand | Self-healing: failed pods/nodes replaced |

## Files

- `user-data.sh` – the bootstrap script the old EC2 instances ran at launch.
  It shows exactly what had to be containerised: Python runtime, dependencies,
  the app, and the systemd unit.

## Migration approach used

1. **Containerise** – translate `user-data.sh` into `app/Dockerfile`
   (same runtime, same port, non-root user).
2. **Externalise config** – move settings from files on disk to environment variables.
3. **Add health endpoints** – `/healthz` and `/readyz` replace the old
   "is systemd running?" check so Kubernetes and the ALB can route safely.
4. **Build the landing zone** – multi-AZ VPC, EKS and ECR with Terraform.
5. **Run in parallel** – deploy to EKS, verify with smoke tests, then shift
   DNS/ALB traffic gradually and keep the EC2 fleet as a rollback path.
6. **Decommission** – scale EC2 to zero once the EKS service has been stable.
