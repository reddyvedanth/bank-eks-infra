# =============================================================================
# PHASE 1 — Minimal stack (use with: -var-file=environments/phase1.tfvars)
# VPC + EKS + Traefik + RDS | NO Calico, Argo CD, VPC endpoints
# =============================================================================

aws_region   = "us-east-1"
project_name = "bank-eks"
environment  = "dev"
cluster_name = "bank-eks-dev"

single_nat_gateway             = true
cluster_endpoint_public_access = true
enable_vpc_endpoints           = false

node_instance_types = ["t3.small"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 3

domain_name = ""

# Phase 1 platform — Traefik only
enable_calico                       = false
enable_traefik                      = true
enable_argocd                       = false
enable_aws_load_balancer_controller = false

app_repo_url    = "https://github.com/your-user/bank-eks-app.git"
app_repo_branch = "main"

