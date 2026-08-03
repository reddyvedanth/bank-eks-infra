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

  # ClusterIssuers via Helm extraObjects (jsonencode avoids conditional object type mismatch).
  cert_manager_letsencrypt_issuers_json = jsonencode([
    {
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
    },
  ])

  cert_manager_selfsigned_issuers_json = jsonencode([
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "selfsigned"
      }
      spec = {
        selfSigned = {}
      }
    },
  ])

  cert_manager_cluster_issuers = jsondecode(
    local.enable_https ? local.cert_manager_letsencrypt_issuers_json : local.cert_manager_selfsigned_issuers_json
  )
}
