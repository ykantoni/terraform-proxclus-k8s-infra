output "longhorn_version" {
  value = helm_release.longhorn.version
}

output "namespace" {
  value = var.namespace
}
