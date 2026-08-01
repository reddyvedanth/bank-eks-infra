# Phase 1 Labs — 12 hands-on tests (KillerKoda style)

**When:** After Phase 1 infra **apply** + app deploy (`deploy-apps.sh`).  
**Goal:** Prove you understand the path *User → Traefik → Pod → RDS*, not just that it “works.”

**Setup reminder:**

```bash
aws eks update-kubeconfig --region us-east-1 --name bank-eks-dev
```

Mark each test ✅ or ❌. **Pass = 10+ of 12** before moving to Phase 2.

---

## How to use these labs

| Symbol | Meaning |
|--------|---------|
| 🎯 | What you must do |
| ✔️ | Pass criteria |
| 💡 | Interview line if you can say this aloud |

---

## Lab 01 — Cluster is alive

**Scenario:** You joined as on-call. Verify the cluster is healthy.

🎯 Run:

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running | grep -v Completed
```

✔️ **Pass:**

- All nodes `Ready`
- No unexpected `Pending` / `CrashLoopBackOff` in core namespaces (`kube-system`, `traefik`)

💡 *"I check nodes first, then non-Running pods cluster-wide."*

---

## Lab 02 — Pod IPs live in the VPC

**Scenario:** Interviewers ask how EKS networking differs from Docker bridge.

🎯 Run:

```bash
kubectl get pods -n three-tier -o wide
aws ec2 describe-vpcs --filters Name=tag:Name,Values=*bank-eks* --query 'Vpcs[0].CidrBlock'
```

✔️ **Pass:**

- Pod IPs start with `10.0.` (your VPC CIDR)
- You can state: *pods get real VPC IPs via aws-vpc-cni, not overlay*

💡 *"On EKS, the VPC CNI assigns secondary ENI IPs — pods are routable inside the VPC."*

---

## Lab 03 — CoreDNS service discovery

**Scenario:** App should not use hardcoded pod IPs.

🎯 Run:

```bash
kubectl run dns-test --rm -it --restart=Never --image=busybox:1.36 -n three-tier -- \
  nslookup api.three-tier.svc.cluster.local
```

✔️ **Pass:**

- Returns a ClusterIP (e.g. `10.100.x.x`)
- You explain: DNS → ClusterIP → kube-proxy → pod IPs

💡 *"Format is `<service>.<namespace>.svc.cluster.local`."*

---

## Lab 04 — Service works inside the cluster

**Scenario:** Frontend must reach API without going through Traefik.

🎯 Run:

```bash
kubectl run curl-test --rm -it --restart=Never --image=curlimages/curl -n three-tier -- \
  curl -s -o /dev/null -w "%{http_code}" http://api.three-tier.svc.cluster.local
```

✔️ **Pass:**

- HTTP status `200` (nginx returns 200 on `/`)

💡 *"ClusterIP is only reachable inside the cluster — that's why we need Ingress for external users."*

---

## Lab 05 — Traefik is the front door

**Scenario:** External user hits the app.

🎯 Run:

```bash
export TRAEFIK_HOST=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$TRAEFIK_HOST"
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/"
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/api"
```

✔️ **Pass:**

- Both return `200`
- You can draw: `Internet → AWS LB → Traefik → Ingress rules → Services`

💡 *"Traefik is the Ingress Controller; the Ingress object defines path rules."*

---

## Lab 06 — Ingress maps paths to the right Service

**Scenario:** Prove `/api` does not go to frontend.

🎯 Run:

```bash
kubectl -n three-tier describe ingress three-tier
kubectl -n three-tier get endpoints frontend api
```

✔️ **Pass:**

- Ingress shows `/` → `frontend`, `/api` → `api`
- Endpoints lists match running pod IPs for each Service

💡 *"Ingress is L7 routing; Endpoints object shows which pod IPs back each Service."*

---

## Lab 07 — `kubectl apply` → running pod (events trail)

**Scenario:** Explain what happens when you deploy (common interview question).

🎯 Run:

```bash
kubectl -n three-tier scale deployment frontend --replicas=3
kubectl -n three-tier get rs,pods -l app=frontend
kubectl get events -n three-tier --sort-by='.lastTimestamp' | tail -15
```

✔️ **Pass:**

- New ReplicaSet or scaled RS
- Events show: Scheduled → Pulling (if new) → Created → Started
- You can narrate: API server → controllers → scheduler → kubelet → CRI → CNI

💡 *"etcd stores desired state; controllers reconcile; scheduler picks node; kubelet starts container."*

---

## Lab 08 — Self-healing (delete a pod)

**Scenario:** A pod crashes. Does the app recover?

🎯 Run:

```bash
kubectl -n three-tier delete pod -l app=frontend --wait=false
sleep 10
kubectl -n three-tier get pods -l app=frontend
```

✔️ **Pass:**

- Replica count back to desired (2 frontend pods)
- New pod has different name than deleted one

💡 *"Deployment controller replaces pods to match replicas — self-healing for pod failure."*

---

## Lab 09 — RDS is reachable from a pod (network path)

**Scenario:** API tier must talk to Postgres in private RDS.

🎯 Run (replace RDS host from terraform output):

```bash
RDS_HOST=$(cd ../terraform && terraform output -raw rds_endpoint | cut -d: -f1)
kubectl run netshoot --rm -it --restart=Never -n three-tier --image=nicolaka/netshoot -- \
  nc -zv "$RDS_HOST" 5432
```

✔️ **Pass:**

- `Connected` or `succeeded` on port 5432

💡 *"RDS is outside K8s; path is pod → VPC routing → RDS SG allows node SG on 5432."*

---

## Lab 10 — Worker nodes are private

**Scenario:** Bank asks: are node instances on the public internet?

🎯 Run:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.providerID}{"\n"}{end}'
# Pick instance ID from providerID, then:
aws ec2 describe-instances --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].[SubnetId,PublicIpAddress,PrivateIpAddress]'
```

✔️ **Pass:**

- `PublicIpAddress` is `null` or empty
- Subnet is a **private** subnet (matches terraform private subnet IDs)

💡 *"Nodes in private subnets; outbound via NAT; ingress via Traefik LB."*

---

## Lab 11 — Break and fix (scale to zero, then restore)

**Scenario:** Simulate bad deploy / ops recovery.

🎯 Run:

```bash
kubectl -n three-tier scale deployment frontend --replicas=0
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/"
kubectl -n three-tier scale deployment frontend --replicas=2
kubectl -n three-tier rollout status deployment/frontend
curl -s -o /dev/null -w "%{http_code}\n" "http://$TRAEFIK_HOST/"
```

✔️ **Pass:**

- First curl fails or non-200 (502/503/404 acceptable)
- After scale up + rollout: curl returns `200`

💡 *"I verify rollout status before declaring incident resolved."*

---

## Lab 12 — Explain without looking (oral test)

**Scenario:** Mock interview — 60 seconds, no terminal.

🎯 **Record yourself** (phone voice memo) answering:

1. User opens `http://<traefik-url>/api` — list every component in order.
2. What is the difference between Service and Ingress?
3. Where does RDS live relative to Kubernetes?

✔️ **Pass:**

- You mention: LB → Traefik → Ingress rule → Service ClusterIP → kube-proxy → pod IP → (for DB) VPC to RDS
- You do not say "Docker network" for pod-to-pod on EKS

💡 This lab has no kubectl — it's what separates deployers from engineers.

---

## Scorecard

| Lab | Topic | ✅ |
|-----|--------|---|
| 01 | Cluster health | |
| 02 | VPC CNI / pod IPs | |
| 03 | CoreDNS | |
| 04 | ClusterIP | |
| 05 | Traefik external URL | |
| 06 | Ingress rules + endpoints | |
| 07 | kubectl apply flow | |
| 08 | Self-healing | |
| 09 | Pod → RDS | |
| 10 | Private nodes | |
| 11 | Break / fix | |
| 12 | Oral explain | |

**≥ 10/12 → ready for Phase 2** ([LEARNING-PHASES.md](LEARNING-PHASES.md))

---

## Phase 1 deploy checklist (before labs)

- [ ] Bootstrap + GitHub CI vars configured
- [ ] Applied with `environments/phase1.tfvars`
- [ ] App deployed (`deploy-apps.sh`) — **skip** `network-policies.yaml`
- [ ] `kubectl -n three-tier get pods` all Running
- [ ] Traefik LB hostname exists

---

## What I suggest you do this week

| Day | Activity |
|-----|----------|
| Mon | Deploy Phase 1 only; don't read Phase 2/3 |
| Tue | Labs 01–04 |
| Wed | Labs 05–08 |
| Thu | Labs 09–11 |
| Fri | Lab 12 + re-run any ❌ |
| Weekend | Explain architecture to a friend or record yourself |

Do **not** enable Calico or Argo until Phase 1 scorecard is green.
