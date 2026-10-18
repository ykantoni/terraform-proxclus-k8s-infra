output "controlplane_ips" {
  value = local.controlplane_ips
}

output "worker_ips" {
  value = [
    for node in values(local.workers) :
    node.ip
  ]
}

output "talosconfig" {
  sensitive = true

  value = data.talos_client_configuration.this.talos_config
}

output "kubeconfig" {
  sensitive = true

  value = talos_cluster_kubeconfig.this.kubeconfig_raw
}
