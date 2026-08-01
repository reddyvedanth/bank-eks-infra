variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "bank-eks"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "bank-eks-dev"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT GW (cheaper dev). Set false for prod HA (one NAT per AZ)."
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Interface VPC endpoints (cost ~$70+/mo). Disable in Phase 1 lab."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Allow kubectl from internet. Disable in prod and use VPN/bastion."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "domain_name" {
  description = "Optional Route53 domain for ACM + Ingress HTTPS. Leave empty for HTTP-only dev."
  type        = string
  default     = ""
}

variable "db_username" {
  type      = string
  default   = "appadmin"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "ChangeMeInProduction123!"
}
