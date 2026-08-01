# Bank EKS Lab — Master Learning Menu

**Use this document as your menu.** Work one phase at a time. Do not skip ahead.

| Phase | Goal | Terraform | Labs | Pass bar |
|-------|------|-----------|------|----------|
| **1** | Understand traffic: User → Traefik → Pod → RDS | `environments/phase1.tfvars` | 12 | ≥ 10/12 |
| **2** | Security + CI: Calico, policies, plan artifacts | `environments/phase2.tfvars` | 10 | ≥ 8/10 |
| **3** | GitOps + full stack: Argo CD, endpoints, banks story | `environments/phase3.tfvars` | 10 | ≥ 8/10 |

---

## Progress tracker (print or copy)

```
PHASE 1  [ ] 01 [ ] 02 [ ] 03 [ ] 04 [ ] 05 [ ] 06 [ ] 07 [ ] 08 [ ] 09 [ ] 10 [ ] 11 [ ] 12
PHASE 2  [ ] 01 [ ] 02 [ ] 03 [ ] 04 [ ] 05 [ ] 06 [ ] 07 [ ] 08 [ ] 09 [ ] 10
PHASE 3  [ ] 01 [ ] 02 [ ] 03 [ ] 04 [ ] 05 [ ] 06 [ ] 07 [ ] 08 [ ] 09 [ ] 10
```

---

## Quick navigation

### Phase 1 — Core platform & networking
| Lab | Title |
|-----|--------|
| [P1-L01](#p1-l01-cluster-health) | Cluster health check |
| [P1-L02](#p1-l02-pod-ips-vpc-cni) | Pod IPs & VPC CNI |
| [P1-L03](#p1-l03-coredns) | CoreDNS service discovery |
| [P1-L04](#p1-l04-clusterip-internal) | ClusterIP internal routing |
| [P1-L05](#p1-l05-traefik-external) | Traefik external access |
| [P1-L06](#p1-l06-ingress-endpoints) | Ingress rules & Endpoints |
| [P1-L07](#p1-l07-kubectl-apply-flow) | kubectl apply → running pod |
| [P1-L08](#p1-l08-self-healing) | Self-healing Deployment |
| [P1-L09](#p1-l09-pod-to-rds) | Pod → RDS network path |
| [P1-L10](#p1-l10-private-nodes) | Private worker nodes |
| [P1-L11](#p1-l11-break-and-fix) | Break and fix rollout |
| [P1-L12](#p1-l12-oral-exam) | Oral exam (no terminal) |

### Phase 2 — Security & Terraform CI
| Lab | Title |
|-----|--------|
| [P2-L01](#p2-l01-calico-running) | Calico installed & healthy |
| [P2-L02](#p2-l02-apply-network-policies) | Apply NetworkPolicies |
| [P2-L03](#p2-l03-policy-blocks-traffic) | Prove policy blocks traffic |
| [P2-L04](#p2-l04-pdb-exists) | PodDisruptionBudget |
| [P2-L05](#p2-l05-node-drain-pdb) | Node drain vs PDB |
| [P2-L06](#p2-l06-terraform-plan-pr) | CI plan on PR |
| [P2-L07](#p2-l07-plan-artifact) | Plan artifact stored |
| [P2-L08](#p2-l08-apply-stored-plan) | Apply uses stored tfplan |
| [P2-L09](#p2-l09-security-groups-rds) | RDS security group path |
| [P2-L10](#p2-l10-phase2-oral) | Phase 2 oral exam |

### Phase 3 — GitOps & production pattern
| Lab | Title |
|-----|--------|
| [P3-L01](#p3-l01-argocd-ui) | Argo CD running |
| [P3-L02](#p3-l02-argocd-sync) | Git push → Argo sync |
| [P3-L03](#p3-l03-gitops-rollback) | GitOps rollback |
| [P3-L04](#p3-l04-vpc-endpoints) | VPC endpoints & NAT |
| [P3-L05](#p3-l05-two-repo-flow) | Two-repo deploy flow |
| [P3-L06](#p3-l06-secrets-not-in-git) | Secrets outside Git |
| [P3-L07](#p3-l07-private-access-story) | Private hosting narrative |
| [P3-L08](#p3-l08-ha-multi-replica) | HA & multi-AZ story |
| [P3-L09](#p3-l09-destroy-gated) | Destroy workflow gated |
| [P3-L10](#p3-l10-final-oral) | Final 15-min architecture oral |

---

# PHASE 1 — Core platform & networking

**Deploy:** `terraform apply -var-file=environments/phase1.tfvars`  
**App:** `./scripts/deploy-phase1.sh` (skips NetworkPolicies)  
**Cost:** ~$150–180/month | **Includes:** VPC, EKS, Traefik, RDS | **Excludes:** Calico, Argo CD, VPC endpoints

### Phase 1 setup checklist
- [ ] Bootstrap + GitHub CI variables
- [ ] PR merged with `phase1.tfvars`
- [ ] `aws eks update-kubeconfig --name bank-eks-dev`
- [ ] App deployed, `kubectl -n three-tier get pods` all Running

---

## P1-L01 — Cluster health

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 15 min |
| **Prerequisites** | Phase 1 apply complete |

### Scenario
You are on-call at 9 AM. Before any change, verify the EKS cluster is healthy.

### Background
A "healthy" cluster means: nodes Ready, control plane reachable, critical system pods Running. Banks run this before every change window.

### Tasks
1. Configure kubectl if needed.
2. List nodes with IPs and status.
3. Find any pod not `Running` or `Completed` cluster-wide.
4. Check Traefik namespace pods.

### Commands
```bash
aws eks update-kubeconfig --region us-east-1 --name bank-eks-dev
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running
kubectl -n traefik get pods
kubectl -n kube-system get pods
```

### Expected output
- Nodes: `STATUS=Ready`, `ROLES` empty or worker labels
- Traefik: at least 1 pod Running
- kube-system: `aws-node`, `coredns`, `kube-proxy` Running on each node

### Pass criteria ✔️
- [ ] All nodes Ready
- [ ] No CrashLoopBackOff in `kube-system` or `traefik`
- [ ] You can name 3 namespaces you checked

### If you fail
| Symptom | Check |
|---------|--------|
| Nodes NotReady | `kubectl describe node`; EC2 console; subnet routes |
| Traefik Pending | Node resources; `kubectl describe pod -n traefik` |
| Unauthorized | `aws sts get-caller-identity`; EKS access entry |

### Interview follow-ups
- *"What do you check first on an EKS incident?"*
- *"Difference between node NotReady and pod Pending?"*

---

## P1-L02 — Pod IPs & VPC CNI

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 20 min |
| **Prerequisites** | P1-L01 pass |

### Scenario
A senior engineer asks: *"On our EKS cluster, what IP does a pod get and why does it matter for RDS and the load balancer?"*

### Background
On EKS with **aws-vpc-cni**, pods get **real VPC IP addresses** (not Docker bridge). ALB/Traefik can use `target-type: ip`. RDS security groups reference VPC routing.

### Tasks
1. List pod IPs in `three-tier`.
2. Get VPC CIDR from AWS or Terraform output.
3. Confirm pod IPs fall inside VPC CIDR.
4. Find the aws-vpc-cni daemonset pods.

### Commands
```bash
kubectl get pods -n three-tier -o wide
kubectl get pods -n kube-system -l k8s-app=aws-node
cd terraform && terraform output vpc_id 2>/dev/null || \
  aws ec2 describe-vpcs --filters Name=tag:Name,Values=*bank-eks* \
  --query 'Vpcs[0].CidrBlock' --output text
```

### Pass criteria ✔️
- [ ] Pod IPs match `10.0.x.x` (or your VPC CIDR)
- [ ] You explain: CNI assigns ENI secondary IPs per node
- [ ] You know this is **not** Flannel/overlay by default on EKS

### If you fail
- Pods have no IP → CNI not running: check `aws-node` pods
- IPs outside VPC → wrong CNI config (rare on managed EKS)

### Interview follow-ups
- *"Why does subnet size matter for EKS?"* (IP exhaustion per ENI limits)
- *"Traefik target-type ip vs instance?"*

---

## P1-L03 — CoreDNS

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 15 min |
| **Prerequisites** | P1-L01 |

### Scenario
The API team hardcoded a pod IP in config. Show why that breaks and how Kubernetes DNS fixes it.

### Background
Services get a stable DNS name: `<name>.<namespace>.svc.cluster.local` → ClusterIP. Pods should use DNS, not IPs.

### Tasks
1. Run `nslookup` from a debug pod for `api.three-tier.svc.cluster.local`.
2. Compare DNS result to `kubectl get svc api -n three-tier`.
3. List CoreDNS pods.

### Commands
```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl get svc api -n three-tier
kubectl run dns-test --rm -it --restart=Never --image=busybox:1.36 -n three-tier -- \
  nslookup api.three-tier.svc.cluster.local
```

### Pass criteria ✔️
- [ ] nslookup returns ClusterIP matching `kubectl get svc`
- [ ] You explain DNS → ClusterIP → kube-proxy → pod IPs

### Interview follow-ups
- *"What happens if CoreDNS is down?"*

---

## P1-L04 — ClusterIP internal routing

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 20 min |
| **Prerequisites** | P1-L03 |

### Scenario
Prove frontend can reach API **without** going through Traefik or the public URL.

### Tasks
1. Curl `http://api.three-tier.svc.cluster.local` from a curl pod.
2. Curl frontend service the same way.
3. Explain why ClusterIP is not reachable from your laptop.

### Commands
```bash
kubectl run curl-test --rm -it --restart=Never --image=curlimages/curl -n three-tier -- \
  curl -sv http://api.three-tier.svc.cluster.local 2>&1 | head -20
kubectl get endpoints api -n three-tier
```

### Pass criteria ✔️
- [ ] HTTP 200 from api service DNS name
- [ ] Endpoints show pod IPs matching `kubectl get pods -o wide`

### Interview follow-ups
- *"ClusterIP vs NodePort vs LoadBalancer?"*

---

## P1-L05 — Traefik external access

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 20 min |
| **Prerequisites** | App deployed, Ingress applied |

### Scenario
QA reports the app is down. Verify external URL for `/` and `/api`.

### Tasks
1. Get Traefik LoadBalancer hostname.
2. Curl root and `/api` paths.
3. Record HTTP status codes.

### Commands
```bash
export TRAEFIK_HOST=$(kubectl -n traefik get svc traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$TRAEFIK_HOST"
curl -s -o /dev/null -w "root: %{http_code}\n" "http://$TRAEFIK_HOST/"
curl -s -o /dev/null -w "api:  %{http_code}\n" "http://$TRAEFIK_HOST/api"
```

### Pass criteria ✔️
- [ ] Both return `200`
- [ ] You can draw: Internet → AWS LB → Traefik → Ingress → Service

### If you fail
| Symptom | Check |
|---------|--------|
| No LB hostname | Traefik svc type LoadBalancer; AWS LB provisioning (2–5 min) |
| 404 on /api | Ingress paths; `kubectl describe ingress -n three-tier` |

---

## P1-L06 — Ingress rules & Endpoints

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 25 min |
| **Prerequisites** | P1-L05 |

### Scenario
`/api` accidentally routes to frontend. Diagnose using Ingress and Endpoints.

### Tasks
1. Describe Ingress `three-tier`.
2. Get Endpoints for frontend and api.
3. Match endpoint IPs to pod IPs per label.

### Commands
```bash
kubectl -n three-tier describe ingress three-tier
kubectl -n three-tier get endpoints frontend api
kubectl -n three-tier get pods -l app=frontend -o wide
kubectl -n three-tier get pods -l app=api -o wide
```

### Pass criteria ✔️
- [ ] Ingress: `/` → frontend, `/api` → api
- [ ] Endpoints IPs ⊆ pod IPs for matching labels

---

## P1-L07 — kubectl apply flow

| | |
|--|--|
| **Difficulty** | Hard |
| **Time** | 30 min |
| **Prerequisites** | P1-L01 |

### Scenario
Interview question: *"Walk me through what happens when I run kubectl apply on a Deployment."*

### Tasks
1. Scale frontend to 3 replicas.
2. Watch ReplicaSet and pods appear.
3. Read last 20 events in namespace.
4. Write 8-step flow on paper (API server → etcd → controllers → scheduler → kubelet → CRI → CNI).

### Commands
```bash
kubectl -n three-tier scale deployment frontend --replicas=3
kubectl -n three-tier get deploy,rs,pods -l app=frontend
kubectl get events -n three-tier --sort-by='.lastTimestamp' | tail -20
```

### Pass criteria ✔️
- [ ] 3 frontend pods Running
- [ ] Events show Scheduled, Pulling (if new), Started
- [ ] You can recite flow without reading docs

---

## P1-L08 — Self-healing

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 15 min |
| **Prerequisites** | P1-L07 |

### Scenario
Simulate kubelet killing a pod. Verify Deployment replaces it.

### Commands
```bash
kubectl -n three-tier delete pod -l app=api --wait=false
sleep 15
kubectl -n three-tier get pods -l app=api
```

### Pass criteria ✔️
- [ ] Replica count returns to 3
- [ ] New pod names differ from deleted pods

---

## P1-L09 — Pod → RDS

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 25 min |
| **Prerequisites** | DB secret applied, RDS from Phase 1 apply |

### Scenario
API cannot connect to database. Test network path from pod to RDS port 5432.

### Commands
```bash
RDS_HOST=$(cd terraform && terraform output -raw rds_endpoint | cut -d: -f1)
kubectl run netshoot --rm -it --restart=Never -n three-tier --image=nicolaka/netshoot -- \
  nc -zv "$RDS_HOST" 5432
```

### Pass criteria ✔️
- [ ] Port 5432 open from pod
- [ ] You explain: pod → VPC route → RDS SG allows **node SG** on 5432

### If you fail
- Check RDS SG ingress from EKS node security group
- Check secret `DB_HOST` matches RDS endpoint hostname

---

## P1-L10 — Private worker nodes

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 25 min |
| **Prerequisites** | P1-L01 |

### Scenario
Auditor asks: *"Are Kubernetes worker instances directly on the internet?"*

### Tasks
1. Get node providerID → EC2 instance ID.
2. Describe instance: public IP, subnet.
3. Confirm subnet is private (no auto public IP on launch).

### Commands
```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
INSTANCE=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | cut -d/ -f5)
aws ec2 describe-instances --instance-ids "$INSTANCE" \
  --query 'Reservations[0].Instances[0].[SubnetId,PublicIpAddress,PrivateIpAddress]' --output table
```

### Pass criteria ✔️
- [ ] `PublicIpAddress` empty/null
- [ ] You explain outbound via NAT, inbound via Traefik LB

---

## P1-L11 — Break and fix

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |
| **Prerequisites** | P1-L05, TRAEFIK_HOST set |

### Scenario
Simulate accidental scale-to-zero. Restore service and verify externally.

### Commands
```bash
kubectl -n three-tier scale deployment frontend --replicas=0
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/"
kubectl -n three-tier scale deployment frontend --replicas=2
kubectl -n three-tier rollout status deployment/frontend --timeout=120s
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/"
```

### Pass criteria ✔️
- [ ] First curl fails or non-200
- [ ] After rollout: 200
- [ ] You waited for `rollout status` before closing incident

---

## P1-L12 — Oral exam

| | |
|--|--|
| **Difficulty** | Hard |
| **Time** | 20 min |
| **Prerequisites** | Labs 01–11 attempted |

### Scenario
Mock interview — **no terminal**, record audio or explain to a friend.

### Questions (answer all)
1. User hits `http://<traefik>/api` — list every hop in order.
2. Service vs Ingress — one sentence each.
3. Where does RDS live vs Kubernetes?
4. Why are worker nodes in private subnets?
5. What does aws-vpc-cni do?

### Pass criteria ✔️
- [ ] Answers mention Traefik, Ingress, Service, kube-proxy, pod IP, VPC, RDS SG
- [ ] No more than one major error

**Phase 1 complete when ≥ 10/12 labs pass.**

---

# PHASE 2 — Security & Terraform CI

**Upgrade:** `terraform apply -var-file=environments/phase2.tfvars` (adds Calico)  
**App:** `./scripts/deploy-apps.sh` (includes NetworkPolicies)  
**Also:** Use Terraform CI PR → plan artifact → merge → apply

### Phase 2 setup checklist
- [ ] Phase 1 ≥ 10/12
- [ ] Calico pods Running in `calico-system`
- [ ] `kubectl apply -f k8s/policies/network-policies.yaml`

---

## P2-L01 — Calico running

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 20 min |

### Scenario
NetworkPolicies were applied but had no effect in Phase 1. Verify Calico is enforcing them now.

### Commands
```bash
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator
kubectl get installation default 2>/dev/null || \
  kubectl get tigerastatus 2>/dev/null || echo "Check Calico CRDs"
```

### Pass criteria ✔️
- [ ] Calico node / typha / apiserver pods Running
- [ ] You explain: AWS VPC CNI = IPs; Calico = policy enforcement on EKS

---

## P2-L02 — Apply NetworkPolicies

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 15 min |

### Commands
```bash
kubectl apply -f k8s/policies/network-policies.yaml
kubectl -n three-tier get networkpolicy
```

### Pass criteria ✔️
- [ ] 3 policies listed: default-deny, allow-frontend, allow-api

---

## P2-L03 — Policy blocks traffic

| | |
|--|--|
| **Difficulty** | Hard |
| **Time** | 45 min |

### Scenario
Prove NetworkPolicy actually blocks unauthorized traffic.

### Tasks
1. Run debug pod **without** `app=frontend` label.
2. Try curl to `api` service — should fail or timeout with default-deny + api policy.
3. Run curl from frontend pod context (or labeled pod) — should work.

### Commands
```bash
# Unauthorized pod (no frontend label)
kubectl run bad-curl --rm -it --restart=Never --image=curlimages/curl -n three-tier -- \
  curl -m 5 -s -o /dev/null -w "%{http_code}\n" http://api.three-tier.svc.cluster.local || echo "blocked/timeout"
```

### Pass criteria ✔️
- [ ] Unauthorized path fails or times out
- [ ] Legitimate frontend→api path still works (P1-L04)
- [ ] You explain default-deny + explicit allow model

### If policies don't block
- Calico not ready (P2-L01)
- Policies not applied
- Some CNIs need time to sync (~30s)

---

## P2-L04 — PodDisruptionBudget

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 20 min |

### Commands
```bash
kubectl -n three-tier get pdb
kubectl -n three-tier describe pdb api-pdb
kubectl -n three-tier get pods -l app=api --no-headers | wc -l
```

### Pass criteria ✔️
- [ ] PDB `minAvailable: 2` with 3 api replicas
- [ ] You explain voluntary vs involuntary disruption

---

## P2-L05 — Node drain vs PDB

| | |
|--|--|
| **Difficulty** | Hard |
| **Time** | 45 min |

### Scenario
Node upgrade scheduled. Drain one node and observe PDB limiting api eviction.

### Commands
```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -n three-tier -o wide --field-selector spec.nodeName="$NODE"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s
kubectl -n three-tier get pods -l app=api -o wide
kubectl uncordon "$NODE"
```

### Pass criteria ✔️
- [ ] Drain may slow/wait because PDB requires 2 api pods available
- [ ] You explain difference between drain and random node failure

### Caution
Run in dev cluster only; uncordon after test.

---

## P2-L06 — CI plan on PR

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Scenario
You change Terraform (e.g. `node_max_size = 5`). Open PR and verify CI runs **plan only**.

### Tasks
1. Branch + trivial tfvars comment change.
2. Open PR to `main`.
3. Verify GitHub Actions: validate + plan jobs succeed.
4. Plan comment appears on PR.

### Pass criteria ✔️
- [ ] PR shows Terraform plan in comment
- [ ] No apply on PR (only plan job)

---

## P2-L07 — Plan artifact stored

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 20 min |

### Tasks
1. On PR workflow run, open **Artifacts**.
2. Find `tfplan-<commit-sha>` containing `tfplan`, `plan.txt`, `plan-metadata.json`.

### Pass criteria ✔️
- [ ] Artifact exists with correct naming from PR comment
- [ ] You explain why binary `tfplan` matters for audited apply

---

## P2-L08 — Apply stored plan

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Scenario
Merge PR. Verify apply downloads **same** tfplan (not fresh plan).

### Tasks
1. Merge PR.
2. Watch apply job logs: "Download stored plan artifact", `terraform apply tfplan`.
3. Confirm no `terraform plan` in apply job before apply.

### Pass criteria ✔️
- [ ] Apply job succeeded
- [ ] Logs show `terraform apply tfplan`
- [ ] You can explain PR head SHA → artifact name on merge

---

## P2-L09 — RDS security group path

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Tasks
1. Get EKS node security group ID from AWS console or CLI.
2. Get RDS security group and ingress rules.
3. Confirm rule: PostgreSQL from node SG.

### Commands
```bash
aws eks describe-cluster --name bank-eks-dev --query 'cluster.resourcesVpcConfig' 
# Find node SG via EC2 instance SGs attached to workers
aws rds describe-db-instances --query 'DBInstances[?DBInstanceIdentifier==`bank-eks-dev-postgres`].VpcSecurityGroups'
```

### Pass criteria ✔️
- [ ] You identify node SG → RDS SG on 5432
- [ ] You explain why `0.0.0.0/0` on RDS would be wrong

---

## P2-L10 — Phase 2 oral exam

### Questions
1. Why Calico on EKS if we already have VPC CNI?
2. What does PDB protect against? What does it NOT protect against?
3. Explain plan artifact → apply workflow in CI.
4. How would you block frontend from talking directly to RDS at pod level?

### Pass criteria ✔️
- [ ] All four answered coherently

**Phase 2 complete when ≥ 8/10 labs pass.**

---

# PHASE 3 — GitOps & production pattern

**Upgrade:** `terraform apply -var-file=environments/phase3.tfvars`  
**Adds:** Argo CD, VPC endpoints, full GitOps  
**Cost:** ~$270–320/month — destroy when not studying

### Phase 3 setup checklist
- [ ] Phase 2 ≥ 8/10
- [ ] `app_repo_url` points to real public `bank-eks-app` repo
- [ ] Argo CD Application Synced

---

## P3-L01 — Argo CD UI

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 20 min |

### Commands
```bash
kubectl -n argocd get pods
kubectl -n argocd get applications
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
kubectl -n argocd get ingress argocd-server 2>/dev/null || \
  kubectl -n traefik get svc traefik
```

### Pass criteria ✔️
- [ ] Argo pods Running
- [ ] Application `three-tier-app` exists
- [ ] You retrieved admin password

---

## P3-L02 — Git push → Argo sync

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Tasks
1. Change frontend replica count in Git (e.g. 2 → 3).
2. Push to `main` on `bank-eks-app`.
3. Watch Argo sync or wait for poll (~3 min).
4. Verify replicas changed in cluster.

### Commands
```bash
kubectl -n argocd get application three-tier-app -w
kubectl -n three-tier get deploy frontend
```

### Pass criteria ✔️
- [ ] Cluster matches Git after sync
- [ ] Argo shows Synced / Healthy

---

## P3-L03 — GitOps rollback

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Tasks
1. Push bad change (e.g. invalid image name).
2. Observe Argo sync failure or pod crash.
3. Revert Git commit and push.
4. Confirm selfHeal/sync restores good state.

### Pass criteria ✔️
- [ ] You fixed by Git revert, not manual kubectl patch (preferred GitOps answer)

---

## P3-L04 — VPC endpoints

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 25 min |

### Scenario
FinOps asks why NAT costs are high. Explain VPC endpoints in your stack.

### Commands
```bash
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$(cd terraform && terraform output -raw vpc_id)
```

### Pass criteria ✔️
- [ ] You list S3 (gateway), ECR, STS, Logs endpoints
- [ ] You explain: endpoints keep AWS API traffic off NAT (cost + security)

---

## P3-L05 — Two-repo deploy flow

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 30 min |

### Oral + practical
Narrate end-to-end:
1. Infra change → which repo? which CI jobs?
2. App change → which repo? Argo vs kubectl CI?

### Pass criteria ✔️
- [ ] Clear separation: infra = Terraform CI; app = Argo CD GitOps

---

## P3-L06 — Secrets not in Git

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 20 min |

### Tasks
1. Confirm `secret.yaml` excluded from Argo sync.
2. Show secret exists in cluster but not required in Git.

### Pass criteria ✔️
- [ ] You explain bank pattern: Secrets Manager / External Secrets / CI-injected secrets

---

## P3-L07 — Private hosting narrative

| | |
|--|--|
| **Difficulty** | Hard |
| **Time** | 30 min |

### Scenario (oral)
*"Host the app so users on the internet cannot reach it — only corporate VPN users."*

### Pass criteria ✔️
- [ ] You mention: internal LB / private API endpoint / VPN / no public node IPs
- [ ] You do NOT say "make Deployment private"

---

## P3-L08 — HA & multi-AZ

| | |
|--|--|
| **Difficulty** | Medium |
| **Time** | 25 min |

### Tasks
1. List AZs for nodes and RDS.
2. Count replicas per tier.
3. Explain what survives single AZ failure.

### Pass criteria ✔️
- [ ] Multi-AZ subnets, multi-replica app, PDB — layered HA story

---

## P3-L09 — Destroy gated

| | |
|--|--|
| **Difficulty** | Easy |
| **Time** | 15 min |

### Tasks
1. GitHub Actions → Terraform workflow → Run workflow → action **destroy**.
2. Note `production` environment approval required (if configured).

### Pass criteria ✔️
- [ ] You understand destroy is manual + gated (do NOT run destroy unless tearing down lab)

---

## P3-L10 — Final oral exam (15 minutes)

### Draw on paper while explaining
1. Full architecture: GitHub → CI → AWS → EKS → Traefik → app → RDS.
2. Two repos, plan artifact, Argo CD.
3. One security layer at network, pod, and data tier.

### Pass criteria ✔️
- [ ] Complete narrative without notes
- [ ] Suitable for senior DevOps bank interview

**Phase 3 complete when ≥ 8/10 labs pass → you are interview-ready on this stack.**

---

## Appendix — Terraform var files

| Phase | File | CI (update workflow when switching) |
|-------|------|-------------------------------------|
| 1 | `environments/phase1.tfvars` | Current default in workflow |
| 2 | `environments/phase2.tfvars` | Change `-var-file` in `.github/workflows/terraform.yml` |
| 3 | `environments/phase3.tfvars` | Same |

## Appendix — Related docs

| Doc | Use |
|-----|-----|
| [BLUEPRINT.md](../BLUEPRINT.md) | Full architecture reference |
| [NETWORKING.md](NETWORKING.md) | Deep networking |
| [PLATFORM.md](PLATFORM.md) | Calico / Traefik / Argo |
| [CI.md](CI.md) | GitHub Actions setup |

---

*Menu version 1.0 — Phase 1: 12 labs | Phase 2: 10 labs | Phase 3: 10 labs | Total: 32*
