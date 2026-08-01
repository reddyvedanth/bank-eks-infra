# -----------------------------------------------------------------------------
# Calico — NetworkPolicy enforcement (EKS keeps AWS VPC CNI for pod IPs)
# -----------------------------------------------------------------------------

resource "helm_release" "tigera_operator" {
  count = var.enable_calico ? 1 : 0

  name             = "tigera-operator"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = "v3.29.1"
  namespace        = "tigera-operator"
  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [
    module.eks,
    aws_eks_addon.vpc_cni,
  ]
}

resource "kubernetes_manifest" "calico_installation" {
  count = var.enable_calico ? 1 : 0

  manifest = {
    apiVersion = "operator.tigera.io/v1"
    kind       = "Installation"
    metadata = {
      name = "default"
    }
    spec = {
      kubernetesProvider = "EKS"
    }
  }

  depends_on = [helm_release.tigera_operator]
}

resource "kubernetes_manifest" "calico_apiserver" {
  count = var.enable_calico ? 1 : 0

  manifest = {
    apiVersion = "operator.tigera.io/v1"
    kind       = "APIServer"
    metadata = {
      name = "default"
    }
    spec = {}
  }

  depends_on = [kubernetes_manifest.calico_installation]
}

# -----------------------------------------------------------------------------
# Traefik — Ingress Controller (L7 routing; creates AWS LB on the Service)
# -----------------------------------------------------------------------------

resource "helm_release" "traefik" {
  count = var.enable_traefik ? 1 : 0

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "33.2.1"
  namespace        = "traefik"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "ingressClass.enabled"
    value = "true"
  }

  set {
    name  = "ingressClass.isDefaultClass"
    value = "true"
  }

  set {
    name  = "ingressClass.name"
    value = "traefik"
  }

  set {
    name  = "providers.kubernetesIngress.enabled"
    value = "true"
  }

  set {
    name  = "providers.kubernetesIngress.ingressClass"
    value = "traefik"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "ports.web.port"
    value = "80"
  }

  depends_on = [
    module.eks,
    aws_eks_addon.coredns,
  ]
}

# -----------------------------------------------------------------------------
# Argo CD — GitOps (syncs bank-eks-app repo to cluster)
# -----------------------------------------------------------------------------

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.10"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Expose UI via Traefik Ingress (optional path /argocd)
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [
    module.eks,
    aws_eks_addon.coredns,
  ]
}

resource "kubernetes_manifest" "argocd_app_three_tier" {
  count = var.enable_argocd ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "three-tier-app"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/part-of" = "bank-eks"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.app_repo_url
        targetRevision = var.app_repo_branch
        path           = var.app_repo_path
        directory = {
          recurse = true
          exclude = "apps/api/secret.yaml"
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "three-tier"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ServerSideApply=true",
        ]
      }
      ignoreDifferences = [{
        group        = "networking.k8s.io"
        kind         = "Ingress"
        jsonPointers = ["/status"]
      }]
    }
  }

  depends_on = [helm_release.argocd]
}

# Traefik Ingress for Argo CD UI (when Traefik enabled)
resource "kubernetes_manifest" "argocd_ingress" {
  count = var.enable_argocd && var.enable_traefik ? 1 : 0

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server"
      namespace = "argocd"
      annotations = {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      }
    }
    spec = {
      ingressClassName = "traefik"
      rules = [{
        http = {
          paths = [{
            path     = "/argocd"
            pathType = "Prefix"
            backend = {
              service = {
                name = "argocd-server"
                port = {
                  number = 80
                }
              }
            }
          }]
        }
      }]
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.traefik,
  ]
}
