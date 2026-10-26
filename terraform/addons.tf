# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# Turns Kubernetes Ingress objects into Application Load Balancers in the
# public subnets. EKS Pod Identity gives only the controller's service
# account the IAM permissions it needs - no node-wide credentials.
# ---------------------------------------------------------------------------
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.10"

  name                            = "${local.name}-aws-lbc"
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.14.0"
  namespace  = "kube-system"

  set = [
    { name = "clusterName", value = module.eks.cluster_name },
    { name = "region", value = var.region },
    { name = "vpcId", value = module.vpc.vpc_id },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
  ]

  depends_on = [module.eks, module.aws_lb_controller_pod_identity]
}

# ---------------------------------------------------------------------------
# EBS CSI driver permissions (the add-on itself is declared in eks.tf) and a
# default encrypted gp3 StorageClass.
# ---------------------------------------------------------------------------
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.10"

  name                      = "${local.name}-ebs-csi"
  attach_aws_ebs_csi_policy = true
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer" # create the volume in the pod's AZ
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# metrics-server: supplies CPU/memory metrics to the Horizontal Pod Autoscaler.
# ---------------------------------------------------------------------------
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.13.0"
  namespace  = "kube-system"

  depends_on = [module.eks]
}
