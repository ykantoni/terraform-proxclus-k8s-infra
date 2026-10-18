variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.19.6"
}

variable "kubeconfig_path" {
  description = "Path to the cluster kubeconfig, used to poll for the Cilium CRDs cilium_lb_ipam depends on"
  type        = string
}

variable "crd_wait_timeout" {
  description = "Seconds to poll for the Cilium CRDs before giving up"
  type        = number
  default     = 60
}

variable "crd_wait_interval" {
  description = "Seconds between polls for the Cilium CRDs"
  type        = number
  default     = 2
}

variable "k8s_service_host" {
  description = "Address Cilium uses to reach the Kubernetes API. localhost targets KubePrism on the node."
  type        = string
  default     = "localhost"
}

variable "k8s_service_port" {
  description = "Port Cilium uses to reach the Kubernetes API"
  type        = number
  default     = 7445
}

variable "lb_ipam_pool_name" {
  description = "Name of the CiliumLoadBalancerIPPool and its matching L2 announcement policy"
  type        = string
  default     = "default"
}

variable "lb_ipam_range" {
  description = "Inclusive address range Cilium LB IPAM assigns to LoadBalancer services"

  type = object({
    start = string
    stop  = string
  })

  validation {
    condition = alltrue([
      can(cidrhost("${var.lb_ipam_range.start}/32", 0)),
      can(cidrhost("${var.lb_ipam_range.stop}/32", 0)),
    ])

    error_message = "lb_ipam_range start and stop must both be IPv4 addresses."
  }
}

variable "l2_announcement_interfaces" {
  description = "Regular expressions matching the node interfaces that answer ARP for LoadBalancer IPs"
  type        = list(string)
  default     = ["^eth[0-9]+"]
}

variable "l2_announce_on_control_plane" {
  description = "Let control-plane nodes answer ARP as well. Off by default so traffic only lands on nodes that run workloads."
  type        = bool
  default     = false
}

variable "k8s_client_rate_limit" {
  description = "API server client rate limit for the Cilium agent, raised to absorb L2 announcement leader election"

  type = object({
    qps   = number
    burst = number
  })

  default = {
    qps   = 50
    burst = 100
  }
}

variable "enable_hubble_ui" {
  description = "Install Hubble Relay and Hubble UI, giving a web dashboard of live CNI traffic (service map, policy verdicts, DNS, L7). Touches no machine configuration and needs no reboot."
  type        = bool
  default     = true
}

variable "hubble_ui_service_type" {
  description = "Kubernetes Service type Hubble UI's web UI (port 80) is exposed as. LoadBalancer (the default) gets an address from Cilium's load_balancer_ip_range, since this cluster runs no ingress controller; see the root README's \"Networking\" section."
  type        = string
  default     = "LoadBalancer"
}

variable "cilium_extra_values" {
  description = "Extra Cilium Helm values merged over the defaults, for example to enable Hubble"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the Cilium release to become ready"
  type        = number
  default     = 900
}
