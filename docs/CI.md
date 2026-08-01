# CI/CD — Terraform via GitHub Actions

Two-repo setup: this document applies to **bank-eks-infra**. App deploys from **bank-eks-app**.

See also [TWO-REPOS.md](TWO-REPOS.md).

## Plan artifact → apply (bank pattern)

```
PR  →  terraform plan -out=tfplan  →  upload artifact tfplan-<sha>
Merge → download tfplan-<sha>  →  terraform apply tfplan
```

**Apply never generates a new plan.** It applies the binary plan file stored during PR review.

| Artifact | Contents | Retention |
|----------|----------|-----------|
| `tfplan-<commit-sha>` | `tfplan`, `plan.txt`, `plan-metadata.json` | 30 days |
| `apply-receipt-<merge-sha>` | metadata + plan text after apply | 90 days |

### Why binary `tfplan`?

`terraform apply tfplan` applies **exactly** what was planned — same resource order, same changes. Interview line: *"We don't apply with `-var-file` on merge; we apply the reviewed plan artifact."*

---

## One-time setup

### 1. Bootstrap AWS (laptop, once)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
terraform output github_variables
```

### 2. Push infra repo

```bash
cd bank-eks-infra
git init && git add . && git commit -m "Infra CI with plan artifacts"
git remote add origin https://github.com/YOU/bank-eks-infra.git
git push -u origin main
```

### 3. GitHub variables (infra repo)

| Variable | Value |
|----------|-------|
| `AWS_REGION` | `us-east-1` |
| `AWS_ROLE_ARN` | bootstrap output |
| `TF_STATE_BUCKET` | bootstrap output |
| `TF_STATE_KEY` | `bank-eks/dev/terraform.tfstate` |
| `TF_STATE_LOCK_TABLE` | bootstrap output |

Secret: `TF_VAR_db_password`

### 4. Push app repo + variables

After infra apply, set in **bank-eks-app**:

| Variable | Value |
|----------|-------|
| `EKS_CLUSTER_NAME` | `bank-eks-dev` |
| `RDS_ENDPOINT` | RDS hostname from `terraform output` |
| `AWS_ROLE_ARN` | same role |
| `AWS_REGION` | `us-east-1` |

Secret: `DB_PASSWORD`

---

## Day-to-day (infra)

1. Branch → change `terraform/`
2. Open PR → CI runs **plan**, comments diff, stores `tfplan-<sha>`
3. Review PR comment + artifact name
4. Merge → CI **apply** downloads artifact, runs `terraform apply tfplan`
5. Deploy app changes separately from **bank-eks-app**

### Manual apply

Actions → Terraform → Run workflow → action `apply` → optional `plan_sha` from PR comment.

### Destroy

Workflow dispatch → `destroy` → requires `production` environment approval.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `No stored plan artifact` on merge | PR must run plan first; direct push to main has no artifact |
| Artifact name mismatch | Apply uses PR head SHA (`HEAD^2` on merge commit) |
| `terraform apply tfplan` stale | Re-open PR to generate fresh plan if main moved |
| App deploy fails | Infra must exist; check `EKS_CLUSTER_NAME` and OIDC role |

---

## Interview talking points

- Separate infra/app repos — blast radius and permissions
- Plan binary in GitHub Artifacts — audit trail of what was approved
- OIDC for both pipelines — no long-lived keys
- Apply gated by `dev` / `production` environments
