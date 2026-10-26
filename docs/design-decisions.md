# Design decisions

## 1. Community Terraform modules for VPC and EKS
**Decision:** use `terraform-aws-modules/vpc` and `terraform-aws-modules/eks`, pinned to a major version.
**Why:** they encode many AWS details (subnet tagging, node IAM roles, access
entries, add-on ordering) that are easy to get wrong by hand, and they are
widely used, so reviewers recognise them.
**Trade-off:** less control over individual resources; upgrades between major
versions need reading the upgrade guide.

## 2. Managed node groups on EC2 (not Fargate, not Auto Mode)
**Decision:** one EKS managed node group of EC2 instances across 3 AZs.
**Why:** this is the most direct path from an EC2 fleet. Teams keep familiar
instance types, can use Spot, and can run DaemonSets (e.g. monitoring agents),
which Fargate does not support.
**Trade-off:** node patching is our responsibility (handled by AMI updates through the node group).
**Next step:** Karpenter or EKS Auto Mode for faster, bin-packed node scaling.

## 3. Private nodes, public load balancer
**Decision:** nodes and pods live only in private subnets; only the ALB and NAT gateway are public.
**Why:** nothing in the cluster is directly reachable from the internet.

## 4. Single vs per-AZ NAT gateway
**Decision:** `single_nat_gateway = true` by default, switchable with one variable.
**Why:** a NAT gateway costs money per hour per AZ. For a short-lived demo one is enough.
**Trade-off:** if that AZ fails, nodes in other AZs lose outbound internet. Set
`single_nat_gateway = false` for production.

## 5. ALB with IP targets
**Decision:** AWS Load Balancer Controller with `target-type: ip`.
**Why:** traffic goes straight to pod IPs, removing the extra NodePort hop and
making health checks reflect real pod readiness.

## 6. EKS Pod Identity instead of node IAM permissions
**Decision:** the load balancer controller gets IAM permissions through EKS Pod Identity.
**Why:** least privilege - only that service account can create load
balancers, not every pod on the node. IMDSv2 with hop limit 1 stops pods
borrowing the node's role.

## 7. Immutable image tags
**Decision:** ECR tags are immutable and deployments use the git SHA as the tag.
**Why:** a tag always means the same image, so rollbacks are exact and auditable.

## 8. No CPU limit vs CPU limit
**Decision:** a modest CPU limit (500m) is set alongside requests.
**Why:** keeps one misbehaving pod from starving neighbours on small demo nodes
and satisfies common policy scanners. On larger production nodes, removing CPU
limits to avoid throttling is a reasonable alternative.

## 9. State management
**Decision:** local state by default, with `backend.tf.example` for S3 using native lockfiles.
**Why:** anyone can clone and try the repo without creating a bucket first; teams switch to remote state in one step.
