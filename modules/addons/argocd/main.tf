# Managed by the kubernetes provider rather than Helm, for the same reason
# as every other addon's namespace (see e.g. modules/addons/prometheus):
# Helm records a release's Secret in its target namespace before applying
# any of that release's own manifests, so a chart cannot create the
# namespace it installs into. Unlike Longhorn or Prometheus's node-exporter,
# none of ArgoCD's components need hostPath/hostNetwork/privileged access,
# so no pod-security label is needed here.
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

locals {
  argocd_values = {
    server = {
      service = {
        type = var.argocd_service_type
      }
    }
  }
}

resource "helm_release" "argocd" {
  depends_on = [
    kubernetes_namespace.argocd,
  ]

  name      = "argocd"
  namespace = var.namespace

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  wait    = true
  timeout = var.helm_timeout

  # Later entries win, so callers can override any of the defaults above.
  values = [
    yamlencode(local.argocd_values),
    yamlencode(var.argocd_extra_values),
  ]
}
