module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  # Public API endpoint restricted to known CIDRs; nodes talk to it privately.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  endpoint_private_access      = true

  # Grants the identity running Terraform cluster-admin via EKS access entries.
  enable_cluster_creator_admin_permissions = true

  # Control plane audit logs to CloudWatch.
  enabled_log_types = ["api", "audit", "authenticator"]

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  addons = {
    coredns    = {}
    kube-proxy = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      # Install the CNI before nodes join so pods get IPs immediately.
      before_compute = true
      # Enforce Kubernetes NetworkPolicy objects natively in the VPC CNI.
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    # EBS volumes for stateful workloads (e.g. Prometheus storage).
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  # EKS managed node group = Amazon EC2 instances in an Auto Scaling group
  # spread across every private subnet (one per AZ).
  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      labels = {
        workload = "general"
      }

      # Require IMDSv2 so pods cannot reuse node credentials via IMDSv1.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }
}
