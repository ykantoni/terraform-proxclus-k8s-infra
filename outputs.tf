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

output "argocd_service_type" {
  description = "Kubernetes Service type argocd-server is exposed as, when enable_argocd = true. When LoadBalancer, find the assigned address with: kubectl -n argocd get svc argocd-server"
  value       = one(module.argocd[*].argocd_service_type)
}

output "argocd_root_app" {
  description = "Name of ArgoCD's root app-of-apps Application, when enable_argocd and argocd_apps_repo_url are set. Check it with: kubectl -n argocd get applications"
  value       = one(module.argocd[*].root_app_name)
}

output "prometheus_service_type" {
  description = "Kubernetes Service type Prometheus's web UI is exposed as, when enable_prometheus = true. When LoadBalancer, find the assigned address with: kubectl -n monitoring get svc kube-prometheus-stack-prometheus"
  value       = one(module.prometheus[*].prometheus_service_type)
}
