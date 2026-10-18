provider "talos" {
}

# Referencing the resource rather than the literal path keeps provider
# configuration ordered after the kubeconfig is written.
provider "helm" {
  kubernetes = {
    config_path = local_sensitive_file.kubeconfig.filename
  }
}

# Used only for the handful of raw Kubernetes objects (namespace labels, and
# the like) that don't belong inside a Helm release, per-addon. Configured the
# same way as the helm provider and for the same reason: ordered after the
# kubeconfig is written.
provider "kubernetes" {
  config_path = local_sensitive_file.kubeconfig.filename
}
