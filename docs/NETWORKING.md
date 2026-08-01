# Kubernetes & EKS Networking — Deep Dive (Interview Lab)

This document maps directly to bank interview questions. Read it **while** you deploy the cluster and run the verification commands below.

---

## 1. The big picture

```
Internet
   │
   ▼
[ ALB ]  ← public subnets, created by AWS Load Balancer Controller
   │
   ▼ (target-type: ip → pod IPs directly)
Pod (10.0.x.x)  ← IP from VPC CIDR via aws-vpc-cni
   │
   ├─► Service ClusterIP (virtual IP, kube-proxy)
   ├─► CoreDNS → another Service
   └─► RDS (10.0.x.x) ← outside cluster, same VPC, SG rules
```

**Key insight for EKS:** Pods get **real VPC IP addresses** (not overlay like Flannel). The **aws-vpc-cni** plugin assigns secondary IPs from the node's ENI to pods.

---

## 2. What happens when you run `kubectl apply -f deployment.yaml`

Step-by-step — memorize this flow:

| Step | Component | What happens |
|------|-----------|--------------|
| 1 | **kubectl** | Sends JSON/YAML to API server with your IAM identity |
| 2 | **API Server** | AuthN (who are you?), AuthZ (RBAC), validation, admission controllers |
| 3 | **etcd** | Persists desired state (Deployment spec) |
| 4 | **Deployment controller** | Sees new Deployment → creates/updates ReplicaSet |
| 5 | **ReplicaSet controller** | Creates Pods to match `replicas: 3` |
| 6 | **Scheduler** | Assigns each Pod to a Node (CPU/mem, affinity, taints) |
| 7 | **kubelet** (on node) | Watches API, sees Pod assigned to its node |
| 8 | **CRI (containerd)** | Pulls image, starts containers |
| 9 | **CNI (aws-vpc-cni)** | Allocates VPC IP, plugs pod into network |
| 10 | **kube-proxy** | Updates iptables/IPVS for Services |

Verify after apply:

```bash
kubectl -n three-tier get deploy,rs,pod
kubectl -n three-tier describe pod <pod-name>   # Events show scheduling + pull
kubectl get events -n three-tier --sort-by='.lastTimestamp'
```

---

## 3. AWS VPC CNI (EKS-specific)

Each EC2 worker node has an ENI. The CNI:

1. Requests additional IP addresses on that ENI (warm pool)
2. Assigns one IP per pod
3. Routes pod traffic through the node's network stack

**Why subnet sizing matters:** A `t3.medium` might support ~17 pods per ENI depending on limits. Too small subnets = IP exhaustion.

```bash
# See CNI pods
kubectl -n kube-system get pods -l k8s-app=aws-node

# CNI config on a node (after SSM/SSH to node)
# /etc/cni/net.d/ ...
```

**Interview answer:** *"On EKS we use the VPC CNI so pods are routable within the VPC without overlay. That lets the ALB use `target-type: ip` and RDS security groups reference node SGs. Tradeoff: IP consumption and ENI limits per instance type."*

---

## 4. Services — ClusterIP, kube-proxy, endpoints

A `Service` is **not** a real pod — it's a stable DNS name + virtual IP.

```bash
kubectl -n three-tier get svc api
kubectl -n three-tier get endpoints api
```

Flow: `curl http://api.three-tier.svc.cluster.local` → CoreDNS resolves → ClusterIP → kube-proxy routes to backend pod IPs.

| Type | Use |
|------|-----|
| **ClusterIP** | Internal only (default) |
| **NodePort** | Opens port on every node (dev/debug) |
| **LoadBalancer** | Cloud LB (ALB/NLB on EKS) |

---

## 5. CoreDNS

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl run -it debug --image=busybox --rm -- nslookup api.three-tier.svc.cluster.local
```

DNS format: `<service>.<namespace>.svc.cluster.local`

---

## 6. Ingress + Traefik (this lab)

Our `Ingress` uses **Traefik** as the Ingress Controller (`ingressClassName: traefik`).

1. Traefik watches Ingress resources cluster-wide
2. Traefik Service type `LoadBalancer` gets an AWS NLB/ELB hostname
3. Traefik routes `/` and `/api` to ClusterIP Services

```bash
kubectl -n traefik get svc traefik
kubectl -n three-tier describe ingress three-tier
```

Optional AWS ALB path: set `enable_aws_load_balancer_controller = true` and use `ingressClassName: alb` (see `docs/PLATFORM.md`).

**Internal-only variant (bank interview):** Internal NLB annotations on Traefik Service, or internal ALB with AWS LBC. Users reach via VPN/Direct Connect.

---

## 7. NetworkPolicies + Calico (enforced)

Calico is installed in **EKS mode** — AWS VPC CNI still assigns IPs; Calico **enforces** NetworkPolicy.

```bash
kubectl get pods -n calico-system
kubectl -n three-tier get networkpolicy
```

Policies in `bank-eks-app/k8s/policies/` are active once Calico APIServer is ready.

---

## 8. Pod → RDS (outside cluster)

RDS is **not** a Kubernetes Service. Connectivity path:

```
api Pod (10.0.12.5) → VPC routing → RDS (10.0.15.89:5432)
```

Requirements:

1. RDS in **private subnets**
2. RDS SG allows **5432 from EKS node security group**
3. App uses RDS **endpoint** hostname (not localhost)
4. NetworkPolicy allows egress 5432 to VPC CIDR (if policies enforced)

Test from a debug pod:

```bash
kubectl run -it netshoot --image=nicolaka/netshoot --rm -n three-tier -- \
  nc -zv <rds-endpoint> 5432
```

---

## 9. Private cluster access (no public internet)

| Actor | How they access |
|-------|-----------------|
| **Engineer kubectl** | VPN → private EKS API endpoint, or bastion/SSM |
| **CI/CD** | Runner in same VPC |
| **End users** | Internal ALB + corporate network |
| **Pods pull images** | ECR via VPC endpoints (we provisioned in Terraform) |

Our Terraform variables:

- `cluster_endpoint_public_access = false` → kubectl only from VPC/VPN
- VPC endpoints for ECR/S3/STS → no NAT for those paths

---

## 10. HA & Pod Disruption

| Mechanism | Purpose |
|-----------|---------|
| **Multi-AZ subnets + 3 replicas** | Survive AZ failure |
| **podAntiAffinity** | Spread pods across nodes |
| **PDB `minAvailable: 2`** | Block voluntary eviction below 2 pods |
| **RollingUpdate** | Controlled deploys |

Simulate node drain (voluntary disruption):

```bash
kubectl get nodes
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# Watch: PDB should prevent too many api pods going down
kubectl -n three-tier get pdb
```

---

## 11. Lab exercises (do these)

### Exercise A — Trace a request
1. Get ALB URL from Ingress
2. `curl -v http://<alb>/`
3. `curl -v http://<alb>/api`
4. Draw the path on paper

### Exercise B — Break networking
1. Remove RDS SG rule → pods can't reach DB
2. Fix it → explain what you checked

### Exercise C — Service discovery
1. `kubectl exec` into frontend pod
2. `curl http://api.three-tier.svc.cluster.local`

### Exercise D — Internal ALB
1. Change Ingress to `scheme: internal`
2. Explain who can still reach the app

### Exercise E — Explain without notes
30-second explanation of `kubectl apply` → running pod.

---

## 12. Interview cheat lines

- *"EKS pods are first-class VPC citizens via the VPC CNI."*
- *"Services are kube-proxy + ClusterIP; Ingress is L7 routing into the cluster."*
- *"For private hosting: private API endpoint, nodes without public IPs, internal ALB, VPC endpoints, RDS in private subnets, secrets in Secrets Manager with IRSA."*
- *"PDB protects availability during upgrades and node drains, not random failures."*
