# Phase 1 — Errors We Hit & Fixes

Short study notes from getting `bank-eks-infra` CI working.

---

## 1. `terraform fmt -check` failed

| | |
|---|---|
| **Problem** | CI failed on `bootstrap/outputs.tf` and `rds.tf` alignment. |
| **Cause** | Files not formatted; local fmt not pushed. |
| **Fix** | `terraform fmt -recursive`; push. CI scopes fmt to repo `.tf` files only. |

---

## 2. `terraform validate` — ClusterIssuer type error

| | |
|---|---|
| **Problem** | `Inconsistent conditional result types` on `irsa.tf` — `spec.acme` vs `spec.selfSigned`. |
| **Cause** | Terraform `? :` needs same object shape on both branches. |
| **Fix** | Split into two `kubernetes_manifest` resources with `count` (later replaced — see #14). |

---

## 3. OIDC — `AssumeRoleWithWebIdentity` (wrong role)

| | |
|---|---|
| **Problem** | Plan failed: not authorized to assume role. |
| **Cause** | `AWS_ROLE_ARN` pointed to old `github-actions-terraform` (trusted only `ultimatenew` repo). |
| **Fix** | Set `AWS_ROLE_ARN` = `arn:aws:iam::202264954476:role/bank-eks-github-actions`. |

---

## 4. GitHub secret / variable on wrong place

| | |
|---|---|
| **Problem** | DB password / vars seemed missing. |
| **Cause** | Secrets on environment `bank-eks-infra`; workflow uses `environment: dev` (Apply). Plan job has no environment. |
| **Fix** | Repo variables for `AWS_ROLE_ARN`, etc. Secrets on **repo** or **`dev`** env. Name: `TF_VAR_db_password` (case-insensitive in GitHub). |

---

## 5. CI still showed old `irsa.tf` error

| | |
|---|---|
| **Problem** | Same validate error after “fix”. |
| **Cause** | Re-running old workflow run; fix not on that commit. |
| **Fix** | Check commit SHA on run; push fix; **new** workflow run (not stale re-run on old SHA). |

---

## 6. Apply — no stored plan artifact

| | |
|---|---|
| **Problem** | `No stored plan artifact 'tfplan-{sha}'`. |
| **Cause** | Push to `main` triggers **Apply**, not Plan. No PR plan uploaded first. |
| **Fix** | PR → Plan (uploads artifact) → review → **merge** → Apply. Or workflow_dispatch plan then apply with `plan_sha`. |

---

## 7. PR opened — no Actions run

| | |
|---|---|
| **Problem** | PR created but CI didn’t start. |
| **Cause** | `phase1-deploy` identical to `main` — no `terraform/**` diff; path filter skips workflow. |
| **Fix** | Push a change under `terraform/` (or workflow file). Empty commit alone doesn’t change paths. |

---

## 8. OIDC still failing — GitHub `sub` format change

| | |
|---|---|
| **Problem** | Correct role ARN + trust `repo:org/repo:*` still denied. |
| **Cause** | GitHub sends `repo:reddyvedanth@26704129/bank-eks-infra@1319174583:pull_request` (numeric IDs). |
| **Fix** | CloudTrail shows real `sub`. Trust policy: exact IDs + `job_workflow_ref` patterns (see `scripts/fix-oidc-trust.sh`). |

---

## 9. OIDC — wrong thumbprints

| | |
|---|---|
| **Problem** | Still `AssumeRoleWithWebIdentity` after trust fix. |
| **Cause** | OIDC provider had stale thumbprint `ab9d02...`; live cert is `2280d493...`. |
| **Fix** | IAM → Identity providers → update thumbprint to `2280d493964640a0929cb51fc04318fc6c38d918` (40 chars). Or `scripts/fix-oidc-thumbprints.sh`. |

---

## 10. Trust policy — `repository` only rejected

| | |
|---|---|
| **Problem** | `MalformedPolicyDocument` when using only `repository` condition. |
| **Cause** | AWS requires `sub` or `job_workflow_ref` in trust (not scoped to `*` alone). |
| **Fix** | Add `sub` with repo IDs + `job_workflow_ref: org/repo/.github/workflows/*`. |

---

## 11. PR plan comment — 403

| | |
|---|---|
| **Problem** | `Resource not accessible by integration` on `github-script`. |
| **Cause** | Plan job `permissions` had only `id-token` + `contents`; no `pull-requests: write`. |
| **Fix** | Add `pull-requests: write` and `issues: write` to Plan job. OIDC was already working (AWS keys in log). |

---

## 12. Plan — `kubernetes_manifest` REST client

| | |
|---|---|
| **Problem** | `cannot create REST client: no client config` on ClusterIssuer. |
| **Cause** | `kubernetes_manifest` needs live EKS at **plan** time; cluster doesn’t exist on first run. |
| **Fix** | ClusterIssuer via cert-manager Helm `extraObjects` in `locals.tf` / `irsa.tf`. |

---

## Quick reference — GitHub vars (infra repo)

| Variable | Example |
|----------|---------|
| `AWS_ROLE_ARN` | `arn:aws:iam::202264954476:role/bank-eks-github-actions` |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `bank-eks-tfstate-vedanth-4476` |
| `TF_STATE_KEY` | `bank-eks/dev/terraform.tfstate` |
| `TF_STATE_LOCK_TABLE` | `bank-eks-tf-locks` |
| Secret | `TF_VAR_db_password` |

---

## Interview one-liner (OIDC)

> Wrong role ARN, stale thumbprints, or GitHub’s new `sub` with repo IDs — check CloudTrail for the actual claim, not docs from old projects.
