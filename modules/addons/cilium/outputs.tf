output "cilium_version" {
  value = helm_release.cilium.version
}

output "load_balancer_ip_range" {
  value = "${var.lb_ipam_range.start}-${var.lb_ipam_range.stop}"
}
