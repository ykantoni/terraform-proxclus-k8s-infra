output "kube_prometheus_stack_version" {
  value = helm_release.kube_prometheus_stack.version
}

output "namespace" {
  value = var.namespace
}

output "prometheus_service_type" {
  description = "Kubernetes Service type Prometheus's web UI is exposed as. When LoadBalancer, find the assigned address with: kubectl -n <namespace> get svc kube-prometheus-stack-prometheus"
  value       = var.prometheus_service_type
}

output "grafana_service_type" {
  description = "Kubernetes Service type Grafana is exposed as. When LoadBalancer, find the assigned address with: kubectl -n <namespace> get svc kube-prometheus-stack-grafana"
  value       = var.grafana_service_type
}
