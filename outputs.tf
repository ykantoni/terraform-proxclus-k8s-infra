output "controlplane_ips" {
  value = module.talos_cluster.controlplane_ips
}

output "worker_ips" {
  value = module.talos_cluster.worker_ips
}

output "kubeconfig" {
  sensitive = true
  value     = module.talos_cluster.kubeconfig
}

output "talosconfig" {
  sensitive = true
  value     = module.talos_cluster.talosconfig
}

output "kubeconfig_path" {
  value = local_sensitive_file.kubeconfig.filename
}

output "load_balancer_ip_range" {
  value = one(module.cilium[*].load_balancer_ip_range)
}

output "grafana_service_type" {
  description = "Kubernetes Service type Grafana is exposed as, when enable_prometheus = true. When LoadBalancer, find the assigned address with: kubectl -n monitoring get svc kube-prometheus-stack-grafana"
  value       = one(module.prometheus[*].grafana_service_type)
}

output "prometheus_service_type" {
  description = "Kubernetes Service type Prometheus's web UI is exposed as, when enable_prometheus = true. When LoadBalancer, find the assigned address with: kubectl -n monitoring get svc kube-prometheus-stack-prometheus"
  value       = one(module.prometheus[*].prometheus_service_type)
}
