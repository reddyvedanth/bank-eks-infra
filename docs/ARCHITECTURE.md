# Architecture — Bank-Grade EKS Lab

## Purpose

Single reference environment for senior DevOps interviews: HA patterns, private networking, certificates, Terraform IaC, and Kubernetes networking you can explain whiteboard-style.

## Topology

```
                         us-east-1 (3 AZs)
┌─────────────────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                                                │
│                                                                 │
│  Public subnets (per AZ)          Private subnets (per AZ)      │
│  ┌──────────────┐                 ┌──────────────────────────┐  │
│  │     ALB      │ ──────────────► │ EKS worker nodes         │  │
│  │ (internet or│   target-type:ip│  ├─ frontend pods        │  │
│  │  internal)   │                 │  ├─ api pods            │  │
│  └──────────────┘                 │  └─ system pods         │  │
│         │                         │         │                │  │
│         │                         │         ▼                │  │
│  ┌──────────────┐                 │  ┌──────────────┐        │  │
│  │ NAT Gateway  │ ◄── outbound ──│  │ RDS Postgres │        │  │
│  │ (1 or 3)     │                 │  │ (private)    │        │  │
│  └──────────────┘                 │  └──────────────┘        │  │
│         │                         │                          │  │
│  ┌──────────────┐                 │  VPC Endpoints:          │  │
│  │ Internet GW  │                 │  S3, ECR, STS, Logs      │  │
│  └──────────────┘                 └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

EKS control plane (AWS managed) — API public or private endpoint
```

## Component map

| Layer | Technology | Production notes |
|-------|------------|------------------|
| IaC | Terraform + AWS modules | Remote state S3 + DynamoDB lock |
| Network | 3 AZ VPC, public/private | Prod: NAT per AZ |
| Compute | EKS managed node groups | ON_DEMAND prod; Spot for batch |
| Ingress | AWS LBC + ALB | Internal scheme for private apps |
| TLS | cert-manager + Let's Encrypt / ACM | ACM on ALB is common at banks |
| Data | RDS PostgreSQL Multi-AZ | Backups, encryption, no public access |
| Identity | IRSA | Per-workload AWS permissions |
| Policy | PDB, NetworkPolicy (intent) | SG for pods on EKS |
| Observability | (add) CloudWatch, Prometheus | Container Insights, alerts |

## Dev vs prod settings

| Setting | Dev (`terraform.tfvars`) | Prod (`environments/prod.tfvars`) |
|---------|--------------------------|-----------------------------------|
| `single_nat_gateway` | `true` | `false` |
| `cluster_endpoint_public_access` | `true` | `false` |
| `node_min_size` | 2 | 3 |
| RDS `multi_az` | false | true |
| `deletion_protection` | false | true |

## Security boundaries

1. **No public IPs on worker nodes** (module default)
2. **RDS SG** — only from EKS node SG on 5432
3. **Secrets** — lab uses K8s Secret; prod uses External Secrets + Secrets Manager
4. **API audit logs** — enabled on cluster
5. **etcd encryption** — secrets encrypted

## What you built vs Jerney / Realplay

| Project | Gap this lab fills |
|---------|-------------------|
| Jerney | EKS Auto Mode — good but hides CNI/node details |
| Realplay | Custom modules — good learning but missing LBC, RDS, PDB |
| **bank-eks (this)** | Full 3-tier + networking docs + prod toggles |

## File layout

```
failure/
├── terraform/          # VPC, EKS, RDS, IRSA, Helm platform
├── k8s/                # Sample 3-tier app + PDB + policies
├── scripts/            # deploy-apps.sh
└── docs/
    ├── ARCHITECTURE.md (this file)
    └── NETWORKING.md   (read this daily)
```
