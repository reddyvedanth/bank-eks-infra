# Bank EKS — Infrastructure

> **Learning menu (32 labs):** [docs/LEARNING-MENU.md](docs/LEARNING-MENU.md)  
> **Full reference:** [BLUEPRINT.md](BLUEPRINT.md)

Terraform for VPC, EKS, RDS, and platform stack:

- **Calico** (NetworkPolicy)
- **Traefik** (Ingress Controller)
- **Argo CD** (GitOps → syncs `bank-eks-app`)
- cert-manager (+ optional AWS ALB controller)

See [docs/PLATFORM.md](docs/PLATFORM.md).

## CI flow (plan artifact → apply)

```
PR opened/updated  →  plan  →  upload artifact tfplan-<commit-sha>
Merge to main      →  apply →  download same tfplan → terraform apply tfplan
```

Apply never runs a fresh plan — it uses the **exact binary plan** reviewers saw on the PR.

## Setup

See [docs/CI.md](docs/CI.md) and [docs/TWO-REPOS.md](docs/TWO-REPOS.md).

```bash
cd terraform/bootstrap   # once, from laptop
cd terraform
terraform init -backend-config=backend.hcl
```

Push to GitHub → CI handles plan/apply.

## Outputs for app repo

After first apply, set these in **bank-eks-app** GitHub variables:

| Variable | Source |
|----------|--------|
| `EKS_CLUSTER_NAME` | `bank-eks-dev` |
| `RDS_ENDPOINT` | `terraform output -raw rds_endpoint` (hostname only) |
| `AWS_ROLE_ARN` | same OIDC role (bootstrap allows both repos) |
| `AWS_REGION` | `us-east-1` |

Secret in app repo: `DB_PASSWORD` (same as `TF_VAR_db_password` in infra).
