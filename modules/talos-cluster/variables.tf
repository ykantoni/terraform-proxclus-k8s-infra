variable "cluster_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "gateway" {
  type = string
}

variable "nameservers" {
  type = list(string)
}

variable "talos_schematic_id_common" {
  description = "Talos Image Factory schematic ID for nodes without a pcigpu"
  type        = string
}

variable "talos_schematic_id_gpu" {
  description = "Talos Image Factory schematic ID for nodes with a pcigpu"
  type        = string
}

variable "controlplane_vip" {
  type    = string
  default = "192.168.1.99"
}

variable "external_ip" {
  description = "Public IP address or hostname a router NATs through to controlplane_vip, so the cluster can be reached from outside the LAN. Added to every node's Talos API certificate SANs and, on control-plane nodes, to the Kubernetes API server's certSANs, so TLS validates against it. The NAT rule itself is out of scope for Terraform; this only makes the certificates accept the address once traffic arrives. Leave null to keep the cluster LAN-only."
  type        = string
  default     = null
}

variable "cni" {
  description = "Cluster CNI. cilium tells Talos to deploy neither Flannel nor kube-proxy, leaving both to Cilium."
  type        = string
  default     = "cilium"

  validation {
    condition     = contains(["flannel", "cilium"], var.cni)
    error_message = "cni must be either flannel or cilium."
  }
}

variable "kube_prism_port" {
  description = "Port the per-node KubePrism API server proxy listens on"
  type        = number
  default     = 7445
}

variable "config_patches" {
  description = "Extra machine configuration patches applied to every node, as YAML strings. Must be static: a value read from the cluster would make the cluster depend on its own addons."
  type        = list(string)
  default     = []
}

variable "controlplane_config_patches" {
  description = "Extra machine configuration patches applied to control-plane nodes only"
  type        = list(string)
  default     = []
}

variable "worker_config_patches" {
  description = "Extra machine configuration patches applied to worker nodes only"
  type        = list(string)
  default     = []
}

variable "wait_for_health" {
  description = "Health check the cluster so dependents only run once the nodes are up. Turn off to plan against a cluster that is down."
  type        = bool
  default     = true
}

variable "wait_for_api" {
  description = "Poll the Kubernetes API at controlplane_vip until it answers before dependents run. Narrower than wait_for_health: it only proves the API server is reachable, not that every node finished Talos's own boot sequence, so it stays useful even when wait_for_health is off. See README's Known issue section for why wait_for_health is off on this cluster."
  type        = bool
  default     = true
}

variable "api_wait_timeout" {
  description = "Seconds to poll the API before giving up, when wait_for_api is on"
  type        = number
  default     = 180
}

variable "api_wait_interval" {
  description = "Seconds between polls, when wait_for_api is on"
  type        = number
  default     = 5
}

variable "nodes" {
  type = map(object({
    vm_id  = number
    name   = string
    ip     = string
    cidr   = number
    mac    = string
    role   = string
    pcigpu = string
  }))
}