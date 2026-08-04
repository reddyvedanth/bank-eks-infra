# Phase 1 Lab — Errors We Hit & How We Fixed Them

Study notes from getting `bank-eks-infra` CI + EKS apply working.  
Each entry: **what you saw** → **why** → **fix** → **remember**.

---

## Quick index

| # | Topic |
|---|--------|
| 1 | `terraform fmt` failed |
| 2 | `terraform validate` — ClusterIssuer type mismatch (first time) |
| 3 | OIDC — wrong IAM role ARN |
| 4 | GitHub secret / variable wrong place or name |
| 5 | CI still shows old error after “fix” |
| 6 | Apply — no stored plan artifact |
| 7 | PR opened — no Actions run |
| 8 | OIDC — GitHub `sub` with numeric repo IDs |
| 9 | OIDC — stale thumbprints |
| 10 | Trust policy — `MalformedPolicyDocument` |
| 11 | PR plan comment — 403 |
| 12 | Plan — `kubernetes_manifest` needs live cluster |
| 13 | Apply — cert-manager `extraObjects` before CRDs |
| 14 | Apply — `extraObjects` wrong type (maps vs YAML strings) |
| 15 | Apply — plan artifact path (`cp` failed) |
| 16 | Stale `tfplan` after failed apply |
| 17 | Apply — `kubernetes_manifest` + CRD timing (discovery cache) |
| 18 | Validate — `locals` conditional type mismatch (second time) |
| 19 | Local `kubectl` — credentials / access denied |
| 20 | **Success** — what finally worked |

---

## 1. `terraform fmt` failed

**What you saw**

```
Run terraform fmt -check -recursive
bootstrap/outputs.tf
rds.tf
Error: Terraform exited with code 3.
```

**Why**  
Exit code **3** = files are not formatted. Local `terraform fmt` was run but changes were not pushed.

**Fix**

```bash
cd terraform
terraform fmt -recursive
git add rds.tf bootstrap/outputs.tf
git commit -m "Fix terraform fmt"
git push
```

CI was also updated to fmt only repo `.tf` files (not `.terraform/modules`):

```bash
find . -name '*.tf' -not -path './.terraform/*' -print0 | xargs -0 terraform fmt -check
```

**Remember**  
Fmt failures are not AWS/OIDC issues — read the file names in the log first.

---

## 2. `terraform validate` — ClusterIssuer type mismatch (first time)

**What you saw**

```
Error: Inconsistent conditional result types
  on irsa.tf line 125, in resource "kubernetes_manifest" "cluster_issuer":
The true value includes object attribute "acme", which is absent in the 'false' value.
```

**Why**  
Terraform’s `? :` operator requires **the same object shape** on both branches. Let’s Encrypt uses `spec.acme`; self-signed uses `spec.selfSigned`.

**Fix (first attempt)**  
Split into two `kubernetes_manifest` resources with `count`:

- `cluster_issuer_letsencrypt` when `domain_name` is set
- `cluster_issuer_selfsigned` when Phase 1 (no domain)

**Remember**  
Different `spec` shapes cannot live in one `? :` manifest block.

---

## 3. OIDC — wrong IAM role ARN

**What you saw**

```
Error: ... not authorized to perform: sts:AssumeRoleWithWebIdentity
```

(or Plan job failed when assuming AWS role)

**Why**  
GitHub variable `AWS_ROLE_ARN` pointed to an old role (`github-actions-terraform`) trusted only for another repo (`ultimatenew`).

**Fix**  
Set repository variable:

```
AWS_ROLE_ARN = arn:aws:iam::202264954476:role/bank-eks-github-actions
```

**Remember**  
Wrong role ARN looks like “OIDC broken” but trust policy on a *different* role is irrelevant.

---

## 4. GitHub secret / variable wrong place or name

**What you saw**

```
TF_VAR_db_password: 
```

(empty in logs — looked like missing secret)

**Why**

- Secret named `TF_VAR_DB_PASSWORD` (wrong case) vs workflow expects `TF_VAR_db_password`
- Secret on environment `bank-eks-infra` but Apply job uses `environment: dev`
- Environment secrets are **not** injected unless the job declares that environment

**Fix**

| Item | Where | Name |
|------|--------|------|
| `AWS_ROLE_ARN`, state bucket vars | Repo **Variables** | see § GitHub config below |
| DB password | Repo **Secrets** or **`dev`** env secrets | `TF_VAR_db_password` |

**Remember**  
GitHub **masks** secrets in logs — empty line often means “hidden”, not “missing”. Confirm in Settings.

---

## 5. CI still shows old error after “fix”

**What you saw**  
Same `irsa.tf` validate error after you thought it was fixed.

**Why**  
Re-ran an **old workflow run** or a commit **before** the fix was pushed.

**Fix**

1. Check **commit SHA** on the failing Actions run
2. Push the fix
3. Start a **new** workflow run on the new commit (don’t “Re-run all jobs” on old SHA)

**Remember**  
Actions re-run = same git tree as original run.

---

## 6. Apply — no stored plan artifact

**What you saw**

```
No stored plan artifact 'tfplan-<sha>'.
```

**Why**  
Push to `main` triggers **Apply**, not Plan. No PR/manual Plan uploaded `tfplan` first.

**Fix** — pick one:

| Path | Steps |
|------|--------|
| PR flow | Open PR → Plan uploads artifact → merge → Apply downloads it |
| Manual | workflow_dispatch **plan** → copy SHA from `tfplan-<sha>` → workflow_dispatch **apply** with `plan_sha` |

**Remember**  
Apply never runs a fresh plan — it applies the **stored binary** `tfplan`.

---

## 7. PR opened — no Actions run

**What you saw**  
PR created but no Terraform workflow started.

**Why**  
Workflow `paths` filter: only runs when `terraform/**` or workflow file changes. Branch identical to `main` → no diff → no run.

**Fix**  
Push a real change under `terraform/` (or touch `.github/workflows/terraform.yml`).

**Remember**  
Empty commits don’t change path filters.

---

## 8. OIDC — GitHub `sub` with numeric repo IDs

**What you saw**  
Correct role + trust `repo:org/repo:*` still denied.

**Why**  
GitHub now sends subjects like:

```
repo:reddyvedanth@26704129/bank-eks-infra@1319174583:pull_request
```

(not the short `repo:reddyvedanth/bank-eks-infra:ref` format)

**Fix**  
Update IAM role trust policy with:

- Exact `sub` patterns with numeric owner/repo IDs
- `job_workflow_ref` conditions

See `scripts/fix-oidc-trust.sh` and bootstrap `main.tf`.

**Remember**  
**CloudTrail** → `AssumeRoleWithWebIdentity` → read the real `sub` claim; don’t copy old docs.

---

## 9. OIDC — stale thumbprints

**What you saw**  
Still `AssumeRoleWithWebIdentity` after trust policy fix.

**Why**  
OIDC identity provider had stale thumbprint (`ab9d02...`); live GitHub cert uses `2280d493...`.

**Fix**

- IAM → Identity providers → `token.actions.githubusercontent.com` → update thumbprint to:
  `2280d493964640a0929cb51fc04318fc6c38d918`
- Or run `scripts/fix-oidc-thumbprints.sh`

**Remember**  
Trust policy + thumbprint are **two** separate OIDC failure modes.

---

## 10. Trust policy — `MalformedPolicyDocument`

**What you saw**

```
MalformedPolicyDocument: ... trust policy ...
```

**Why**  
AWS rejected a trust policy scoped only with `repository` — needs `sub` or `job_workflow_ref` (not wildcard alone in some setups).

**Fix**  
Add `sub` with repo IDs + `job_workflow_ref: org/repo/.github/workflows/*` in bootstrap trust policy.

**Remember**  
IAM trust JSON has strict condition key rules — validate in IAM console policy editor.

---

## 11. PR plan comment — 403

**What you saw**

```
Resource not accessible by integration
```

(on `github-script` posting plan to PR)

**Why**  
Plan job had `permissions: id-token, contents` but not `pull-requests: write`.

**Fix**  
Add to Plan job:

```yaml
permissions:
  id-token: write
  contents: read
  pull-requests: write
  issues: write
```

**Remember**  
OIDC to AWS was already working; this was **GitHub API** permissions only.

---

## 12. Plan — `kubernetes_manifest` needs live cluster

**What you saw**

```
Error: cannot create REST client: no client config
```

(on `kubernetes_manifest` for ClusterIssuer at **plan** time)

**Why**  
`kubernetes_manifest` talks to the cluster API during plan. On **first** deploy there is no cluster yet.

**Fix (attempt)**  
Move ClusterIssuer into cert-manager Helm `extraObjects` (led to apply errors #13–#14 — see below).

**Remember**  
Helm releases can target a cluster that doesn’t exist yet at plan time in some setups; `kubernetes_manifest` is stricter.

---

## 13. Apply — cert-manager `extraObjects` before CRDs

**What you saw**

```
helm_release.cert_manager: Creating...
Error: unable to build kubernetes objects from release manifest:
  no matches for kind "ClusterIssuer" in version "cert-manager.io/v1"
  ensure CRDs are installed first
```

**Why**  
`extraObjects` tried to create `ClusterIssuer` in the **same** Helm release as cert-manager, before CRDs were registered in the API.

**Fix**  
Remove `extraObjects` from cert-manager chart; install cert-manager only first.

**Remember**  
**CRDs must exist** before any custom resource (ClusterIssuer, Ingress with unusual classes, etc.).

---

## 14. Apply — `extraObjects` wrong type

**What you saw**  
Terraform/Helm error on `extraObjects` — chart expected YAML strings, not HCL maps.

**Why**  
cert-manager chart templates each `extraObjects` entry as a **string** (tpl), not a nested object.

**Fix**  
Use `yamlencode()` per object in a list of strings in `locals.tf`.

**Remember**  
Read the **chart’s values schema** — “list of maps” vs “list of YAML strings” matters.

---

## 15. Apply — plan artifact path (`cp` failed)

**What you saw**  
Apply job failed copying `tfplan` — file not at expected path inside downloaded zip.

**Why**  
GitHub artifact zip layout varies: sometimes `terraform/tfplan`, sometimes flat `tfplan` at root.

**Fix**  
Apply job checks both:

```bash
if [ -f /tmp/plan-artifact/terraform/tfplan ]; then
  SRC=/tmp/plan-artifact/terraform
else
  SRC=/tmp/plan-artifact
fi
cp "$SRC/tfplan" terraform/tfplan
```

**Remember**  
Artifact **name** is `tfplan-<commit-sha>`; that SHA is `plan_sha`, not the artifact run ID.

---

## 16. Stale `tfplan` after failed apply

**What you saw**  
Re-running Apply on the same `plan_sha` after a partial/failed apply caused confusing errors.

**Why**  
State changed mid-apply; old binary plan no longer matches reality.

**Fix**

1. Fix Terraform code
2. **New** workflow_dispatch **plan**
3. **New** apply with **new** `plan_sha`
4. Never re-apply a plan from a failed run

**Remember**  
One plan → one apply. Failed apply → new plan.

---

## 17. Apply — `kubernetes_manifest` + CRD timing (discovery cache)

**What you saw**

```
Error: API did not recognize GroupVersionKind from manifest (CRD may not be installed)
  with kubernetes_manifest.cluster_issuer_selfsigned[0]
no matches for kind "ClusterIssuer" in group "cert-manager.io"
```

**Why**  
Even with `time_sleep` after cert-manager, the **Kubernetes Terraform provider** caches API discovery at apply start. CRDs installed mid-apply aren’t visible to `kubernetes_manifest`.

**Fix**  
Drop `kubernetes_manifest` for issuers. Use a **second** `helm_release` (bedag **raw** chart) that applies ClusterIssuer YAML **after** cert-manager `wait = true`.

**Remember**  
“CRDs exist in cluster” ≠ “Terraform kubernetes provider sees them in same apply.” Prefer Helm for post-CRD resources in one pipeline.

---

## 18. Validate — `locals` conditional type mismatch (second time)

**What you saw**

```
Error: Inconsistent conditional result types
  on locals.tf line 23, in locals:
  cluster_issuer_resources = local.enable_https ? [ letsencrypt ] : [ selfsigned ]
Type mismatch for object attribute "spec": "acme" absent in false value.
```

**Why**  
Same as #2 — `? :` between two different issuer object shapes inside a list.

**Fix**

```hcl
cluster_issuer_resources = concat(
  local.enable_https ? [] : [local.cluster_issuer_selfsigned],
  local.enable_https ? [local.cluster_issuer_letsencrypt] : [],
)
```

**Remember**  
`concat` with one empty branch avoids the type equality check.

---

## 19. Local `kubectl` — credentials / access denied

**What you saw**

```
aws eks update-kubeconfig --name bank-eks-dev --region us-east-1   # succeeded
kubectl get nodes
error: You must be logged in to the server
(the server has asked for the client to provide credentials)
```

**Why**

- `update-kubeconfig` only sets **cluster URL + auth plugin** — not who is allowed in.
- Cluster uses `authentication_mode = "API"` (EKS Access Entries).
- CI applied with `bank-eks-github-actions` → that role has an access entry.
- Your laptop used `arn:aws:iam::202264954476:root` → **no** access entry.

**Fix**

```bash
PRINCIPAL=$(aws sts get-caller-identity --query Arn --output text)

aws eks create-access-entry \
  --cluster-name bank-eks-dev --region us-east-1 \
  --principal-arn "$PRINCIPAL" --type STANDARD

aws eks associate-access-policy \
  --cluster-name bank-eks-dev --region us-east-1 \
  --principal-arn "$PRINCIPAL" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster

kubectl get nodes
```

Prefer an **IAM user** over root for daily lab use.

**Remember**  
EKS auth = **IAM principal** + **access entry** + kubeconfig. Three different layers.

---

## 20. Success — what finally worked

**cert-manager flow (final)**

1. `helm_release.cert_manager` — CRDs via `values: { crds.enabled: true }`, `wait = true`
2. `helm_release.cluster_issuer` — bedag `raw` chart with `local.cluster_issuer_resources`
3. Phase 1 (`domain_name = ""`) → self-signed `ClusterIssuer` named `selfsigned`

**CI flow (final)**

```
validate → plan → upload tfplan-<sha> → apply (download same tfplan) → cluster ACTIVE
```

**Commits on `phase1-deploy` (examples)**

- `8431b2a` — ClusterIssuer after CRDs (removed extraObjects)
- `b579d9f` — Helm raw chart for issuers
- `627c3e3` — `concat` fix for locals

---

## GitHub config reference

| Variable / secret | Value |
|-------------------|--------|
| `AWS_ROLE_ARN` | `arn:aws:iam::202264954476:role/bank-eks-github-actions` |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `bank-eks-tfstate-vedanth-4476` |
| `TF_STATE_KEY` | `bank-eks/dev/terraform.tfstate` |
| `TF_STATE_LOCK_TABLE` | `bank-eks-tf-locks` |
| Secret `TF_VAR_db_password` | your RDS password |

**Repo IDs (OIDC trust)**  
Owner `26704129`, infra repo `1319174583`, app repo `1319174961`

---

## Interview one-liners

| Topic | One line |
|-------|----------|
| OIDC failures | Wrong role ARN, stale thumbprint, or new GitHub `sub` format — check CloudTrail. |
| Plan artifacts | Apply uses frozen `tfplan`; failed apply needs new plan. |
| cert-manager | CRDs first; don’t apply ClusterIssuer in same Helm pass as chart install. |
| Terraform types | `? :` needs identical shapes; use `count` or `concat`. |
| EKS kubectl | Access Entries map IAM principals to cluster policies; kubeconfig alone isn’t enough. |

---

## When you’re done studying

**Actions → Terraform → destroy** (requires `production` environment approval).  
Keep **bootstrap** (`terraform/bootstrap/`) — S3 state bucket, DynamoDB locks, OIDC role.

Next session: **plan → apply** again (new `plan_sha`).
