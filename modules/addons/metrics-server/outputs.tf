output "metrics_server_version" {
  value = helm_release.metrics_server.version
}

output "namespace" {
  value = var.namespace
}
