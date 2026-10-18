output "runtime_class_name" {
  value = var.runtime_class_name
}

output "gpu_node_names" {
  description = "Kubernetes Node names labelled and targeted as having a GPU"
  value       = local.gpu_node_names
}

output "namespace" {
  value = var.namespace
}
