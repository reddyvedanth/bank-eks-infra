# Push to GitHub — step-by-step

Bootstrap is done locally. CI only works after code is on GitHub.

Your GitHub org/username: **reddyvedanth** (from bootstrap tfvars)

---

## Step 1 — Create empty repos on GitHub

Go to https://github.com/new and create **two** repos (no README, no .gitignore — empty):

| Repo name | Visibility |
|-----------|------------|
| `bank-eks-infra` | Private (recommended) |
| `bank-eks-app` | Private |

URLs will be:
- `https://github.com/reddyvedanth/bank-eks-infra`
- `https://github.com/reddyvedanth/bank-eks-app`

---

## Step 2 — Push infra repo

```bash
cd /Users/vedanthreddy/failure/bank-eks-infra

git init
git add .
git status   # confirm terraform.tfvars is NOT listed (secrets)
git commit -m "Phase 1: EKS lab infra with Terraform CI"

git branch -M main
git remote add origin https://github.com/reddyvedanth/bank-eks-infra.git
git push -u origin main
```

If `git init` says "reinitialized" or wrong root — you may have a parent git repo. Fix:

```bash
# Only if push tries to upload your whole home folder:
rm -rf .git   # inside bank-eks-infra only
git init
```

---

## Step 3 — Push app repo

```bash
cd /Users/vedanthreddy/failure/bank-eks-app

git init
git add .
git commit -m "Three-tier k8s manifests"

git branch -M main
git remote add origin https://github.com/reddyvedanth/bank-eks-app.git
git push -u origin main
```

---

## Step 4 — GitHub Variables (infra repo)

**Settings → Secrets and variables → Actions**

From `terraform/bootstrap` output:

```bash
terraform output github_variables
```

| Variable | Secret? |
|----------|---------|
| `AWS_REGION` | variable |
| `AWS_ROLE_ARN` | variable |
| `TF_STATE_BUCKET` | variable |
| `TF_STATE_KEY` | variable |
| `TF_STATE_LOCK_TABLE` | variable |
| `TF_VAR_db_password` | **secret** |

---

## Step 5 — First CI run (PR, not direct push)

```bash
cd /Users/vedanthreddy/failure/bank-eks-infra
git checkout -b phase1-first-deploy
git push -u origin phase1-first-deploy
```

On GitHub: **Compare & pull request** → base `main` → open PR.

CI runs **plan** (cheap). Review comment. Then **merge** → **apply** (EKS bill starts).

---

## Files NOT pushed (by design)

| File | Why |
|------|-----|
| `terraform.tfvars` | passwords / local config |
| `bootstrap/terraform.tfvars` | same |
| `.terraform/` | provider binaries |
| `*.tfstate` | state (lives in S3 after CI) |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Push asks for huge upload | Wrong git root — init inside `bank-eks-infra` only |
| CI fails `Could not assume role` | `AWS_ROLE_ARN` wrong; check bootstrap output |
| CI fails state bucket | `TF_STATE_*` vars wrong |
| `terraform.tfvars` in commit | `git rm --cached` it; never commit secrets |

---

## Order summary

```
1. Create GitHub repos (empty)
2. Push bank-eks-infra
3. Push bank-eks-app
4. Set GitHub variables + secret
5. Open PR → plan
6. Merge → apply
7. deploy-phase1.sh + LEARNING-MENU labs
```
