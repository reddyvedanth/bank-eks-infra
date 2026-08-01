variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "bank-eks"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "github_org" {
  description = "GitHub org or username"
  type        = string
}

variable "github_repos" {
  description = "GitHub repos allowed to assume the CI role (infra + app)"
  type        = list(string)
  default     = ["bank-eks-infra", "bank-eks-app"]
}

variable "terraform_state_key" {
  description = "S3 key for main stack state file"
  type        = string
  default     = "bank-eks/dev/terraform.tfstate"
}

variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC provider. Set false if one already exists in the account (only one per URL allowed)."
  type        = bool
  default     = false
}
