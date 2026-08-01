# -----------------------------------------------------------------------------
# EKS — managed node groups (better for learning networking than Auto Mode)
# Auto Mode hides node/CNI details; banks still ask about aws-vpc-cni and ENIs
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  authentication_mode = "API"

  # Encrypt Kubernetes secrets in etcd
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # Audit trail — required in regulated environments
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  enable_cluster_creator_admin_permissions = true

  # IRSA — IAM Roles for Service Accounts (pods get scoped AWS permissions)
  enable_irsa = true

  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Spread nodes across AZs for HA
      subnet_ids = module.vpc.private_subnets

      labels = {
        role = "general"
      }

      tags = local.common_tags
    }
  }

  tags = local.common_tags
}

# Core addons — explicit so you know what runs on the cluster
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  # Let EKS pick compatible version unless you need to pin
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks]
}
