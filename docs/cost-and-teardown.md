# Cost and teardown

EKS is billed by the hour, so treat a live deployment as temporary: apply,
demonstrate, capture screenshots, destroy.

## Rough hourly cost (default settings)

Approximate on-demand list prices; check the
[AWS Pricing Calculator](https://calculator.aws/) for your region before deploying.

| Resource | Quantity | Approx. per hour |
|---|---|---|
| EKS control plane | 1 | ~$0.10 |
| EC2 t3.medium nodes | 3 | ~$0.13 (lower with `SPOT`) |
| NAT gateway | 1 | ~$0.05 + data processing |
| Application Load Balancer | 1 | ~$0.02 + LCU usage |
| CloudWatch logs, KMS, ECR storage | – | a few cents |
| **Total** | | **roughly $0.30/hour, about $7/day** |

## Keeping it cheap

- Use `node_capacity_type = "SPOT"` and `single_nat_gateway = true` (defaults in the example tfvars).
- Run `terraform apply` only when you need a live demo; most checks run without AWS (`make test lint validate`).
- Create an [AWS Budget](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html) alert (for example $10) before the first apply.

## Teardown

```bash
./scripts/teardown.sh
```

The script deletes the Kubernetes Ingress **first** so the AWS Load Balancer
Controller can remove the ALB. If you run `terraform destroy` while the
Ingress still exists, the ALB and its security groups are left behind and
block deletion of the VPC.

After teardown, confirm in the AWS console that there are no remaining:
load balancers, NAT gateways, Elastic IPs, or EC2 instances.
