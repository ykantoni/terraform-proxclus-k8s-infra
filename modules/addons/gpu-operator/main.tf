# Which Kubernetes Node object corresponds to each GPU-mapped IP has to be
# resolved at apply time: var.nodes (the root module's source of truth for
# pcigpu) knows each node's Proxmox name and static IP, but nothing pins the
# Kubernetes Node name to either of those — Talos derives it from the node's
# hostname, which this cluster never sets explicitly (see modules/talos-cluster).
# Matching on the InternalIP address Kubernetes itself reports sidesteps that
# guesswork entirely.
data "kubernetes_nodes" "all" {}

locals {
  node_internal_ips = {
    for node in data.kubernetes_nodes.all.nodes :
    node.metadata[0].name => try(
      [
        for address in node.status[0].addresses :
        address.address if address.type == "InternalIP"
      ][0],
      null
    )
  }

  gpu_node_names = [
    for name, ip in local.node_internal_ips :
    name if contains(var.gpu_node_ips, ip)
  ]

  # ip -> Kubernetes Node name, for the label resource below. Only entries
  # for GPU nodes are needed, but keying this by IP (not name) is what
  # matters: it lets that resource's for_each use var.gpu_node_ips, which is
  # static and known at plan time, instead of this data-source-derived
  # mapping, which is not.
  gpu_ip_to_node_name = {
    for name, ip in local.node_internal_ips :
    ip => name if ip != null && contains(var.gpu_node_ips, ip)
  }
}

# Managed by the kubernetes provider rather than Helm, for the same reason as
# modules/addons/prometheus's namespace: Helm records a release's Secret in
# its target namespace before applying any of that release's own manifests,
# so a chart cannot create the namespace it installs into.
resource "kubernetes_namespace" "gpu_operator" {
  metadata {
    name = var.namespace

    labels = {
      # The device-plugin, dcgm-exporter and validator DaemonSets need
      # hostPath access to the host's /dev, /proc and driver libraries to
      # reach the GPU — all forbidden under the restricted Pod Security
      # Standard. Same shape of problem as modules/addons/longhorn and
      # modules/addons/prometheus's node-exporter, solved the same way.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# The Operator has no way to target only GPU nodes without Node Feature
# Discovery (nfd.enabled below is false — see README), so it's told which
# nodes have a GPU the same way modules/addons/nvidia-device-plugin used to:
# by label, derived from pcigpu via var.gpu_node_ips.
#
# Two labels, not one:
#   - feature.node.kubernetes.io/pci-10de.present is what the Operator's own
#     controller checks in place of NFD's auto-detection (0x10de is NVIDIA's
#     PCI vendor ID) to decide which nodes get its operand DaemonSets.
#   - var.gpu_node_label (nvidia.com/gpu.present by default) is kept only so
#     apps/ollama's existing nodeSelector default keeps matching; nothing in
#     the Operator itself depends on this specific label once NFD is off.
#
# for_each is keyed on var.gpu_node_ips rather than local.gpu_node_names on
# purpose: the names come from data.kubernetes_nodes.all, and that data
# source is read through the kubernetes provider, whose config depends on
# local_sensitive_file.kubeconfig. On `terraform destroy` that file is also
# being destroyed, so Terraform treats anything read through the provider as
# unknown until apply — an unknown for_each set is a hard error. IPs come
# straight from a variable, so they stay known even mid-destroy; the (still
# data-source-derived) node name only has to be a plain attribute below,
# which is allowed to be unknown.
resource "kubernetes_labels" "gpu_node" {
  for_each = toset(var.gpu_node_ips)

  api_version = "v1"
  kind        = "Node"

  metadata {
    name = local.gpu_ip_to_node_name[each.value]
  }

  labels = {
    "feature.node.kubernetes.io/pci-10de.present" = "true"
    (var.gpu_node_label)                          = "true"
  }

  force = true
}

resource "helm_release" "gpu_operator" {
  depends_on = [
    kubernetes_namespace.gpu_operator,
    kubernetes_labels.gpu_node,
  ]

  name      = "gpu-operator"
  namespace = var.namespace

  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"
  version    = var.gpu_operator_version

  wait    = true
  timeout = var.helm_timeout

  # Later entries win, so callers can override any of the defaults above.
  values = [
    yamlencode({
      operator = {
        runtimeClass = var.runtime_class_name
      }

      # Talos's siderolabs/nvidia-open-gpu-kernel-modules-production system
      # extension already loads the driver (see
      # modules/talos-cluster/patches/nvidia-modules.patch.yaml) and
      # siderolabs/nvidia-container-toolkit-production already registers the
      # "nvidia" containerd runtime — an immutable-OS extension, not
      # something the Operator's own driver/toolkit installers (built for a
      # mutable host) can manage. Letting both try would fight over the same
      # kernel modules and containerd config.
      driver = {
        enabled = false
      }

      toolkit = {
        enabled = false
      }

      # See the comment on kubernetes_labels.gpu_node above: this module
      # already knows which nodes have a GPU from pcigpu, so NFD's
      # autodetection would only be a second, independent source of truth
      # for the same fact.
      nfd = {
        enabled = false
      }

      devicePlugin = {
        enabled = true
      }

      gfd = {
        enabled = var.enable_gfd
      }

      dcgmExporter = {
        enabled = var.enable_dcgm_exporter

        serviceMonitor = {
          # Only ever created when the Prometheus Operator's ServiceMonitor
          # CRD actually exists in the cluster (module.prometheus), or this
          # release fails to apply its own manifests.
          enabled = var.enable_dcgm_exporter && var.enable_prometheus
        }
      }
    }),
    yamlencode(var.gpu_operator_extra_values),
  ]
}
