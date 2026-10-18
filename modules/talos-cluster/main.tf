locals {
  controlplanes = {
    for key, node in var.nodes :
    key => node
    if node.role == "controlplane"
  }

  workers = {
    for key, node in var.nodes :
    key => node
    if node.role == "worker"
  }

  controlplane_ips = [
    for node in values(local.controlplanes) :
    node.ip
  ]

  bootstrap_node = values(local.controlplanes)[0]

  cluster_endpoint = "https://${var.controlplane_vip}:6443"

  controlplane_patches = concat(
    [
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "Layer2VIPConfig"
        name       = var.controlplane_vip
        link       = "eth0"
      })
    ],
    # Kubernetes API server cert only needs the extra SAN on control-plane
    # nodes, since that is the only role that runs kube-apiserver.
    var.external_ip != null ? [
      yamlencode({
        cluster = {
          apiServer = {
            certSANs = [var.external_ip]
          }
        }
      })
    ] : [],
    var.cni == "cilium" ? [
      yamlencode({
        cluster = {
          network = {
            cni = {
              name = "none"
            }
          }

          proxy = {
            disabled = true
          }
        }
      })
    ] : []
  )
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name = var.cluster_name

  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = local.controlplane_ips

  nodes = [
    for node in values(var.nodes) :
    node.ip
  ]
}

data "talos_machine_configuration" "node" {

  for_each = var.nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint

  machine_type = each.value.role == "controlplane" ? "controlplane" : "worker"

  machine_secrets = talos_machine_secrets.this.machine_secrets

  talos_version = var.talos_version

  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            disk = "/dev/sda"

            image = "factory.talos.dev/metal-installer/${try(each.value.pcigpu, null) != null ? var.talos_schematic_id_gpu : var.talos_schematic_id_common}:${var.talos_version}"
          }

          features = {
            kubePrism = {
              enabled = true
              port    = var.kube_prism_port
            }
          }

          network = {

            interfaces = [
              {
                interface = "eth0"

                addresses = [
                  "${each.value.ip}/${each.value.cidr}"
                ]

                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.gateway
                  }
                ]
              }
            ]

            nameservers = var.nameservers
          }
        }
      })
    ],
    # Talos API (apid) cert, one per node, so talosctl also validates against
    # external_ip regardless of which node's traffic the router NATs to.
    var.external_ip != null ? [
      yamlencode({
        machine = {
          certSANs = [var.external_ip]
        }
      })
    ] : [],
    var.config_patches,
    each.value.role == "controlplane" ? concat(local.controlplane_patches, var.controlplane_config_patches) : var.worker_config_patches
  )
}
resource "talos_machine_configuration_apply" "node" {
  for_each = var.nodes

  node     = each.value.ip
  endpoint = each.value.ip

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.node[each.key].machine_configuration
  config_patches = concat(
    try(each.value.pcigpu, null) != null ? [
      file("${path.module}/patches/nvidia-modules.patch.yaml"),
      # Exposes /var/lib/ollama-models to the kubelet's mount namespace, the
      # same way modules/addons/longhorn/patches does for /var/lib/longhorn.
      # Only the GPU node needs it: apps/ollama's "local" PersistentVolume
      # (kubernetes_persistent_volume_v1.ollama_models there) is pinned to
      # this node and this path by default. Without this patch the kubelet
      # reports "MountVolume.NewMounter initialization failed ... path
      # does not exist" even once the directory itself is created.
      file("${path.module}/patches/ollama-models-mounts.patch.yaml"),
    ] : []
  )
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.node
  ]

  node     = local.bootstrap_node.ip
  endpoint = local.bootstrap_node.ip

  client_configuration = talos_machine_secrets.this.client_configuration
}
# A narrower, faster gate than data.talos_cluster_health: it only proves the
# API server answers, which is all Helm-based addons actually need. Unlike
# the health check, it does not look at Talos boot stage, so it stays usable
# even when wait_for_health is off to work around the NVIDIA-extension boot
# stage bug (see README's Known issue section). Deliberately does not use
# curl -f: this cluster's API server has anonymous auth disabled, so every
# endpoint — /version included — answers 401 even once fully up, and -f would
# treat that as failure. Any HTTP response at all, even a 401, proves the API
# server is listening and evaluating requests; only a connection-level
# failure (nothing listening yet) should count as "not ready". No
# authentication needed for the probe itself, so this needs no kubeconfig,
# and can run as soon as bootstrap has been requested.
#
# Provisioners only run once, at creation, so this polls exactly once per
# cluster lifetime: a fresh `apply` after `destroy` empties state and recreates
# it, but an already-satisfied wait is not repeated by routine incremental
# applies against a cluster that is already up.
resource "terraform_data" "wait_for_api" {
  count = var.wait_for_api ? 1 : 0

  depends_on = [
    talos_machine_configuration_apply.node,
    talos_machine_bootstrap.this,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      end=$(( $(date +%s) + ${var.api_wait_timeout} ))
      until curl -sSk --max-time 5 "https://${var.controlplane_vip}:6443/version" >/dev/null 2>&1; do
        if [ "$(date +%s)" -ge "$end" ]; then
          echo "Kubernetes API at ${var.controlplane_vip}:6443 did not answer within ${var.api_wait_timeout}s" >&2
          exit 1
        fi
        sleep ${var.api_wait_interval}
      done
    EOT
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]

  node     = local.bootstrap_node.ip
  endpoint = local.bootstrap_node.ip

  client_configuration = talos_machine_secrets.this.client_configuration
}

# Bootstrapping only means Talos accepted the call. Anything that talks to
# Kubernetes has to wait for the nodes to actually come up, which is what this
# gates on.
data "talos_cluster_health" "this" {
  count = var.wait_for_health ? 1 : 0

  depends_on = [
    talos_machine_configuration_apply.node,
    talos_machine_bootstrap.this,
  ]

  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = local.controlplane_ips

  control_plane_nodes = local.controlplane_ips

  worker_nodes = [
    for node in values(local.workers) :
    node.ip
  ]

  # Keep the Kubernetes checks on: they are the only ones that prove the API
  # server answers requests, which is what Helm needs. Talos itself skips the
  # checks that cannot pass without a CNI — node readiness and coredns — once
  # the machine config says cni: none, and the kube-proxy check skips when the
  # DaemonSet is absent. Skipping them here would leave only Talos-level checks,
  # none of which touch Kubernetes at all.
  skip_kubernetes_checks = false
}

