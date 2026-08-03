data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"

  # Production: 3 AZs. Slice ensures we never request more AZs than the region has.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  enable_https = var.domain_name != ""

  # cert-manager extraObjects must be YAML strings (chart tpl's each item as string).
  cert_manager_cluster_issuers = local.enable_https ? [
    yamlencode({
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
    }),
    ] : [
    yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "selfsigned"
      }
      spec = {
        selfSigned = {}
      }
    }),
  ]
}
