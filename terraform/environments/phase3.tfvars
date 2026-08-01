# =============================================================================
# PHASE 3 — Full production pattern (after Phase 2 labs ≥ 8/10)
# + Argo CD GitOps, VPC endpoints, full two-repo flow
# =============================================================================

aws_region   = "us-east-1"
project_name = "bank-eks"
environment  = "dev"
cluster_name = "bank-eks-dev"

single_nat_gateway             = true
cluster_endpoint_public_access = true
enable_vpc_endpoints           = true

node_instance_types = ["t3.small"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 4

domain_name = ""

enable_calico                       = true
enable_traefik                      = true
enable_argocd                       = true
enable_aws_load_balancer_controller = false

app_repo_url    = "https://github.com/your-user/bank-eks-app.git"
app_repo_branch = "main"
