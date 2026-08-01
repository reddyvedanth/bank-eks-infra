# Platform Addons — Calico, Traefik, Argo CD

## What runs on the cluster

| Component | Role | Namespace |
|-----------|------|-----------|
| **AWS VPC CNI** | Pod IPs from VPC (EKS addon) | `kube-system` |
| **Calico** | Enforces `NetworkPolicy` | `calico-system`, `tigera-operator` |
| **Traefik** | **Ingress Controller** (L7 routing) | `traefik` |
| **Argo CD** | GitOps — syncs `bank-eks-app` | `argocd` |
| **cert-manager** | TLS certificates | `cert-manager` |
| **AWS LBC** | ALB Ingress (optional, off by default) | `kube-system` |

## Traffic flow (Traefik)

```
Internet
   │
   ▼
AWS Load Balancer  ← Traefik Service type LoadBalancer
   │
   ▼
Traefik Ingress Controller  (ingressClass: traefik)
   │
   ├── /      → frontend Service → pods
   ├── /api   → api Service → pods
   └── /argocd → argocd-server (optional UI)
```

Interview line: *"Traefik is the Ingress Controller — it watches Ingress resources and routes HTTP. AWS VPC CNI assigns pod IPs; Traefik does not replace the CNI."*

## Calico + NetworkPolicy

EKS default CNI does **not** enforce NetworkPolicy. Calico is installed in **EKS mode**:

- AWS VPC CNI still assigns pod IPs
- Calico APIServer enforces policies in `bank-eks-app/k8s/policies/`

Verify:

```bash
kubectl get pods -n calico-system
kubectl -n three-tier get networkpolicy
# Test: policy should block unexpected traffic when Calico is healthy
```

## Argo CD GitOps

Argo CD watches **bank-eks-app** and auto-syncs `k8s/` (excludes `secret.yaml`).

```bash
# Admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# App sync status
kubectl -n argocd get applications
```

Update `app_repo_url` in `terraform.tfvars.example` before apply.

**DB secret** is not in Git — apply manually or via app CI:

```bash
kubectl -n three-tier create secret generic api-db-credentials ...
```

## ALB vs Traefik

| | Traefik (default) | AWS LBC + ALB |
|--|-------------------|---------------|
| Ingress class | `traefik` | `alb` |
| AWS integration | NLB/ELB via Service LB | Native ALB annotations |
| Enable | `enable_traefik = true` | `enable_aws_load_balancer_controller = true` |

Do not enable both as default Ingress classes without careful split.

## Terraform variables

```hcl
enable_calico                       = true
enable_traefik                      = true
enable_argocd                       = true
enable_aws_load_balancer_controller = false
app_repo_url                        = "https://github.com/you/bank-eks-app.git"
```
