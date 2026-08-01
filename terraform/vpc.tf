# -----------------------------------------------------------------------------
# VPC — 3-tier network foundation
# Public subnets: ALB only
# Private subnets: EKS nodes, RDS
# -----------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, az in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  private_subnets = [for k, az in local.azs : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required for AWS Load Balancer Controller to provision ALBs
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# VPC Endpoints — reduce NAT traffic, keep AWS API calls private
# Interview point: S3/ECR via NAT is expensive; endpoints are cheaper + more secure
# -----------------------------------------------------------------------------

module "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoints_sg[0].security_group_id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
  }

  tags = local.common_tags
}

module "vpc_endpoints_sg" {
  count = var.enable_vpc_endpoints ? 1 : 0

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-vpc-endpoints"
  description = "Allow HTTPS from VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = [var.vpc_cidr]

  egress_rules = ["all-all"]

  tags = local.common_tags
}
