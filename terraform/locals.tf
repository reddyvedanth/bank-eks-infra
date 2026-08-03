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

  cluster_issuer_selfsigned = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned"
    }
    spec = {
      selfSigned = {}
    }
  }

  cluster_issuer_letsencrypt = {
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

  # concat avoids Terraform conditional type mismatch (acme vs selfSigned spec shapes).
  cluster_issuer_resources = concat(
    local.enable_https ? [] : [local.cluster_issuer_selfsigned],
    local.enable_https ? [local.cluster_issuer_letsencrypt] : [],
  )
}
