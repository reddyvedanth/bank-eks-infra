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
}
