output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "rds_endpoint" {
  description = "RDS hostname (private — only reachable from cluster)"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_database_name" {
  value = "appdb"
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "platform_addons" {
  description = "Installed platform components"
  value = {
    calico  = var.enable_calico
    traefik = var.enable_traefik
    argocd  = var.enable_argocd
    aws_lbc = var.enable_aws_load_balancer_controller
  }
}

output "argocd_admin_password_command" {
  description = "Retrieve initial Argo CD admin password"
  value       = var.enable_argocd ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo" : "Argo CD disabled"
}

output "traefik_lb_command" {
  description = "Get Traefik LoadBalancer URL"
  value       = var.enable_traefik ? "kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'" : "Traefik disabled"
}
