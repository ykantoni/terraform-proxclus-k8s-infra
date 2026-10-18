output "namespace" {
  value = var.namespace
}

output "argocd_service_type" {
  value = var.argocd_service_type
}

output "root_app_name" {
  value = var.apps_repo_url != "" ? var.apps_root_app_name : null
}
