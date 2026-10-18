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

# A chart rather than a kubernetes_manifest for the same reason as cilium's
# cilium-lb-ipam: the Application CRD only exists once helm_release.argocd
# has applied, so it can't be schema-checked at plan time.
resource "helm_release" "root_app" {
  count = var.apps_repo_url != "" ? 1 : 0

  depends_on = [
    helm_release.argocd,
  ]

  name      = "argocd-root-app"
  namespace = var.namespace

  chart = "${path.module}/charts/argocd-root-app"

  values = [
    yamlencode({
      name           = var.apps_root_app_name
      repoURL        = var.apps_repo_url
      targetRevision = var.apps_repo_revision
      path           = var.apps_repo_path
    })
  ]
}
