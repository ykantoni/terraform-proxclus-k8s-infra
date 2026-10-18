locals {
  longhorn_values = {
    # Longhorn's chart already creates a StorageClass named "longhorn"; making
    # it the cluster default is what lets PVCs provision dynamically without
    # naming storageClassName. defaultClassReplicaCount also sets the
    # non-default StorageClasses' fallback, so both settings share one input.
    persistence = {
      defaultClass             = true
      defaultClassReplicaCount = var.replica_count
      defaultFsType            = "ext4"
    }

    # Matches the /var/lib/longhorn kubelet bind mount added to every node's
    # machine configuration; see modules/addons/longhorn/patches. The iSCSI
    # and util-linux tooling Longhorn's engine shells out to comes from the
    # siderolabs/iscsi-tools and siderolabs/util-linux-tools extensions in
    # customization.yaml, not from anything this chart installs.
    defaultSettings = {
      defaultDataPath = var.data_path
    }
  }
}

# Managed by the kubernetes provider rather than Helm: Helm records a
# release's Secret in its target namespace before applying any of that
# release's own manifests, so a chart cannot create the namespace it installs
# into, and create_namespace=true creates a plain namespace outside any
# release's ownership, which a templated Namespace resource would then
# conflict with on install. Managing it here directly sidesteps both.
resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = var.namespace

    labels = {
      # Longhorn's engine and CSI plugin pods mount host block devices and
      # /var/lib/longhorn directly, which the restricted Pod Security
      # Standard forbids.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "longhorn" {
  depends_on = [
    kubernetes_namespace.longhorn
  ]

  name      = "longhorn"
  namespace = var.namespace

  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.longhorn_version

  wait    = true
  timeout = var.helm_timeout

  # Later entries win, so callers can override any of the defaults above.
  values = [
    yamlencode(local.longhorn_values),
    yamlencode(var.longhorn_extra_values),
  ]
}
