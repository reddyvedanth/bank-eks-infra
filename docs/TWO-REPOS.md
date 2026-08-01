# Bank EKS Lab — Two Repository Layout

Production teams split **infra** and **app** so blast radius, permissions, and release cadence stay separate.

```
┌─────────────────────┐     ┌─────────────────────┐
│   bank-eks-infra    │     │   bank-eks-app      │
│   Terraform + CI    │     │   k8s manifests     │
└──────────┬──────────┘     └──────────┬──────────┘
           │                           │
           ▼                           ▼
        AWS VPC/EKS/RDS            kubectl apply
```

## Repositories

| Repo | Path locally | GitHub name (example) |
|------|--------------|------------------------|
| Infra | `bank-eks-infra/` | `bank-eks-infra` |
| App | `bank-eks-app/` | `bank-eks-app` |

### Publish to GitHub

```bash
# Infra
cd bank-eks-infra
git init && git add . && git commit -m "Infra: EKS terraform with plan artifact CI"
git remote add origin https://github.com/YOUR_USER/bank-eks-infra.git
git branch -M main && git push -u origin main

# App
cd ../bank-eks-app
git init && git add . && git commit -m "App: three-tier k8s manifests"
git remote add origin https://github.com/YOUR_USER/bank-eks-app.git
git branch -M main && git push -u origin main
```

## Plan artifact workflow (infra repo)

This is what banks expect — **apply matches reviewed plan**.

| Step | What happens |
|------|----------------|
| 1. PR | `plan` job runs `terraform plan -out=tfplan` |
| 2. Store | Artifact uploaded as `tfplan-<pr-head-sha>` (30 day retention) |
| 3. Review | Plan text commented on PR; artifact name shown |
| 4. Merge | `apply` job downloads `tfplan-<pr-head-sha>` |
| 5. Apply | `terraform apply tfplan` — **no new plan** |

### Merge commit SHA vs PR SHA

GitHub merge commits have two parents. Apply uses `HEAD^2` (feature branch tip) to find the PR plan artifact — the commit reviewers actually approved.

### Direct push to main (no PR)

No stored artifact → apply **fails**. Always use PRs for infra changes.

### Manual apply

Actions → Run workflow → `apply` → set `plan_sha` from PR comment.

## Bootstrap OIDC (both repos)

`terraform/bootstrap` trusts **both** GitHub repos for the same IAM role:

```hcl
github_repos = ["bank-eks-infra", "bank-eks-app"]
```

## Interview talking points

- *"Infra and app repos — different teams, different pipelines, same cluster."*
- *"Terraform plan binary stored as CI artifact; apply uses that file, not `-auto-approve` with a fresh plan."*
- *"OIDC for both pipelines — no static AWS keys."*
