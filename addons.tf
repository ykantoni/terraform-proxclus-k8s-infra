# One module per addon. Addons that need machine-config changes keep them as
# static patch files and hand them to module.talos_cluster through its
# *_config_patches inputs; see modules/talos-cluster/README.md.

locals {
  # pcigpu is already the cluster's single source of truth for "this node has
  # a GPU" — it drives the schematic (gpu vs common) and the nvidia-modules
  # kernel patch in modules/talos-cluster. Deriving the device plugin's
  # presence from the same field, instead of a second independent enable
  # flag, means there is nothing to keep in sync: map a GPU to a node here
  # and the plugin follows automatically.
  gpu_node_ips = [
    for node in local.nodes : node.ip
    if try(node.pcigpu, null) != null
  ]
}

module "cilium" {
  source = "./modules/addons/cilium"

  count = var.cni == "cilium" ? 1 : 0

  cilium_version         = var.cilium_version
  kubeconfig_path        = local_sensitive_file.kubeconfig.filename
  k8s_service_host       = var.k8s_service_host
  k8s_service_port       = var.kube_prism_port
  lb_ipam_range          = var.load_balancer_ip_range
  enable_hubble_ui       = var.enable_hubble_ui
  hubble_ui_service_type = var.hubble_ui_service_type

  depends_on = [
    module.talos_cluster,
    local_sensitive_file.kubeconfig,
  ]
}

module "longhorn" {
  source = "./modules/addons/longhorn"

  count = var.enable_longhorn ? 1 : 0

  longhorn_version = var.longhorn_version
  replica_count    = var.longhorn_replica_count

  # module.talos_cluster's health check skips node-readiness and coredns once
  # cni is cilium, since Talos itself never brings up a CNI in that mode. So
  # depending on it only proves Talos booted, not that pods can get an IP.
  # Longhorn's manager DaemonSet needs pod networking to come up at all, so it
  # must also wait on module.cilium's helm_release, which is the thing that
  # actually proves the CNI is ready. Referencing the bare module here (no
  # index) is still valid when cni is flannel and module.cilium has zero
  # instances; module.talos_cluster's own health check covers CNI readiness
  # in that case instead, since Talos runs Flannel itself.
  depends_on = [
    module.talos_cluster,
    module.cilium,
    local_sensitive_file.kubeconfig,
  ]
}

module "metrics_server" {
  source = "./modules/addons/metrics-server"

  count = var.enable_metrics_server ? 1 : 0

  metrics_server_version = var.metrics_server_version

  # Same reasoning as module.longhorn: needs pod networking up, which
  # module.talos_cluster's own health check only guarantees when cni is
  # flannel, so it also waits on module.cilium's helm_release when cni is
  # cilium.
  depends_on = [
    module.talos_cluster,
    module.cilium,
    local_sensitive_file.kubeconfig,
  ]
}

module "prometheus" {
  source = "./modules/addons/prometheus"

  count = var.enable_prometheus ? 1 : 0

  kube_prometheus_stack_version = var.kube_prometheus_stack_version
  grafana_admin_password        = var.grafana_admin_password

  # Same CNI reasoning as module.longhorn and module.metrics_server. Also
  # waits on module.longhorn directly: this module's PVCs (storage_class
  # defaults to "longhorn") need Longhorn's CSI controller actually running
  # to provision, not just its own helm_release having eventually turned
  # Ready under this module's separate wait=true.
  depends_on = [
    module.talos_cluster,
    module.cilium,
    module.longhorn,
    local_sensitive_file.kubeconfig,
  ]
}

module "gpu_operator" {
  source = "./modules/addons/gpu-operator"

  count = length(local.gpu_node_ips) > 0 ? 1 : 0

  gpu_node_ips         = local.gpu_node_ips
  gpu_operator_version = var.gpu_operator_version
  enable_dcgm_exporter = var.enable_dcgm_exporter
  enable_gfd           = var.enable_gfd
  enable_prometheus    = var.enable_prometheus

  # Same CNI reasoning as module.longhorn and module.metrics_server. Also
  # waits on module.prometheus directly (bare reference, valid at count 0 the
  # same way module.longhorn is referenced elsewhere in this file): when
  # enable_dcgm_exporter and enable_prometheus are both true, this module's
  # ServiceMonitor needs the Prometheus Operator's CRD for it to already
  # exist, not just that module's own helm_release having eventually turned
  # Ready under this module's separate wait=true.
  depends_on = [
    module.talos_cluster,
    module.cilium,
    module.prometheus,
    local_sensitive_file.kubeconfig,
  ]
}

module "argocd" {
  source = "./modules/addons/argocd"

  count = var.enable_argocd ? 1 : 0

  argocd_version      = var.argocd_version
  argocd_service_type = var.argocd_service_type
  apps_repo_url       = var.argocd_apps_repo_url
  apps_repo_revision  = var.argocd_apps_repo_revision

  # Same CNI reasoning as module.longhorn. Depending on module.cilium as a
  # whole (not just its helm_release) also means cilium_lb_ipam's address
  # pool exists before this release's wait=true starts waiting for
  # argocd-server's LoadBalancer IP.
  depends_on = [
    module.talos_cluster,
    module.cilium,
    local_sensitive_file.kubeconfig,
  ]
}
