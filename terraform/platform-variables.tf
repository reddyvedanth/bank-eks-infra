# -----------------------------------------------------------------------------
# Platform addons: Calico (NetworkPolicy), Traefik (Ingress), Argo CD (GitOps)
# -----------------------------------------------------------------------------

variable "enable_calico" {
  description = "Install Calico for NetworkPolicy enforcement on EKS (works with AWS VPC CNI)"
  type        = bool
  default     = true
}

variable "enable_traefik" {
  description = "Install Traefik as the cluster Ingress Controller"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Install Argo CD for GitOps deployments from bank-eks-app repo"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller (ALB Ingress). Off by default when using Traefik."
  type        = bool
  default     = false
}

variable "app_repo_url" {
  description = "Git URL for bank-eks-app (Argo CD sync source)"
  type        = string
  default     = "https://github.com/your-user/bank-eks-app.git"
}

variable "app_repo_branch" {
  type    = string
  default = "main"
}

variable "app_repo_path" {
  description = "Path in app repo Argo CD syncs (relative paths under k8s/)"
  type        = string
  default     = "k8s"
}
