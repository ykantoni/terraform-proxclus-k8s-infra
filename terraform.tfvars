cluster_name     = "proxclus"
talos_version    = "v1.13.8"
controlplane_vip = "192.168.1.99"

cni            = "cilium"
cilium_version = "1.19.6"

enable_longhorn = true

# Prometheus/Alertmanager/Grafana PVCs default to the "longhorn" StorageClass,
# so this depends on enable_longhorn = true above (order in this file doesn't
# matter to Terraform, only that both are true).
enable_prometheus = true

# Off because cp1, worker2 and worker3 never reach Talos stage "running": the
# NVIDIA extensions in the shared image wait forever for a GPU those nodes do
# not have, so the "all nodes to finish boot sequence" check can never pass.
# Kubernetes itself is unaffected. Turn this back on once only GPU nodes carry
# the NVIDIA extensions.
wait_for_health = false

load_balancer_ip_range = {
  start = "192.168.1.60"
  stop  = "192.168.1.98"
}

gateway = "192.168.1.1"

nameservers = [
  "192.168.1.1",
  "1.1.1.1"
]
