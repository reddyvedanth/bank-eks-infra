# -----------------------------------------------------------------------------
# IRSA — AWS Load Balancer Controller + cert-manager
# -----------------------------------------------------------------------------

module "aws_load_balancer_controller_irsa" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name}-aws-lbc"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa[0].iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
  ]
}

data "aws_route53_zone" "this" {
  count = local.enable_https ? 1 : 0

  name         = var.domain_name
  private_zone = false
}

module "cert_manager_irsa" {
  count = local.enable_https ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name}-cert-manager"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.this[0].arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.16.2"

  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "crds.enabled"
    value = "true"
  }

  dynamic "set" {
    for_each = local.enable_https ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.cert_manager_irsa[0].iam_role_arn
    }
  }

  depends_on = [module.eks]
}

# ClusterIssuer CRD must exist before issuer manifests (extraObjects races CRD registration).
resource "time_sleep" "wait_for_cert_manager_crds" {
  create_duration = "90s"
  depends_on      = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "cluster_issuer_letsencrypt" {
  count = local.enable_https ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "devops@${var.domain_name}"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          dns01 = {
            route53 = {
              region = var.aws_region
            }
          }
        }]
      }
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager_crds]
}

resource "kubernetes_manifest" "cluster_issuer_selfsigned" {
  count = local.enable_https ? 0 : 1

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned"
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager_crds]
}
