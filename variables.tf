variable "cluster_name" {
  description = "Talos/Kubernetes cluster name"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version used for generated machine configuration"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the machine configuration; must be supported by talos_version"
  type        = string
  default     = "1.36.0"
}

variable "gateway" {
  description = "Default network gateway"
  type        = string
}

variable "nameservers" {
  description = "DNS servers"
  type        = list(string)
}

variable "controlplane_vip" {
  type    = string
  default = "192.168.1.99"
}

variable "external_ip" {
  description = "Public IP address or hostname a router NATs through to controlplane_vip, so the cluster can be reached from outside the LAN. Added to the Talos and Kubernetes API certificate SANs; the NAT rule itself is configured on the router, not by Terraform. Leave null (the default) to keep the cluster LAN-only."
  type        = string
  default     = "91.152.206.161"
}

variable "cni" {
  description = "Cluster CNI. cilium keeps Talos from deploying Flannel and kube-proxy and installs Cilium in their place."
  type        = string
  default     = "cilium"

  validation {
    condition     = contains(["flannel", "cilium"], var.cni)
    error_message = "cni must be either flannel or cilium."
  }
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.19.6"
}

variable "kube_prism_port" {
  description = "Port the per-node KubePrism API server proxy listens on"
  type        = number
  default     = 7445
}

variable "k8s_service_host" {
  description = "Host name for Cilium"
  type        = string
  default     = "localhost"
}

variable "enable_hubble_ui" {
  description = "Install Hubble Relay + Hubble UI behind Cilium, giving a web dashboard of live CNI traffic (service map, policy verdicts, DNS, L7 flows). Touches no machine configuration and needs no reboot, so it defaults on. Ignored when cni != \"cilium\"."
  type        = bool
  default     = true
}

variable "hubble_ui_service_type" {
  description = "Kubernetes Service type Hubble UI's web UI is exposed as. LoadBalancer (the default) gets an address from Cilium's load_balancer_ip_range, since this cluster runs no ingress controller; see the root README's \"Networking\" section."
  type        = string
  default     = "LoadBalancer"
}

variable "wait_for_health" {
  description = "Health check the cluster before installing addons. Turn off to plan against a cluster that is down."
  type        = bool
  default     = true
}

variable "wait_for_api" {
  description = "Poll the Kubernetes API at controlplane_vip until it answers before installing addons. Narrower than wait_for_health: it only proves the API server is reachable, so it stays useful even when wait_for_health is off."
  type        = bool
  default     = true
}

variable "enable_longhorn" {
  description = "Install Longhorn as the cluster's default CSI provider for dynamic PV provisioning. Also adds the /var/lib/longhorn kubelet mount to every node's machine configuration; turning this on reboots every node."
  type        = bool
  default     = false
}

variable "longhorn_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = "1.8.1"
}

variable "longhorn_replica_count" {
  description = "Default number of replicas Longhorn keeps for each volume"
  type        = number
  default     = 3
}

variable "enable_metrics_server" {
  description = "Install metrics-server, so kubectl top and the HorizontalPodAutoscaler have resource metrics to read. Unlike enable_longhorn, this touches no machine configuration and needs no reboot, so it defaults on."
  type        = bool
  default     = true
}

variable "metrics_server_version" {
  description = "metrics-server Helm chart version"
  type        = string
  default     = "3.14.0"
}

variable "enable_prometheus" {
  description = "Install kube-prometheus-stack (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics) for cluster monitoring. Its PVCs default to the \"longhorn\" StorageClass (see modules/addons/prometheus's storage_class default), so this needs enable_longhorn = true too. Touches no machine configuration and needs no reboot on its own."
  type        = bool
  default     = false
}

variable "kube_prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "90.0.0"
}

variable "grafana_admin_password" {
  description = "Grafana admin login password. Defaults to the chart's own default (\"prom-operator\"); override before relying on enable_prometheus's default LoadBalancer exposure, which puts Grafana's login page on the LAN."
  type        = string
  default     = "prom-operator"
  sensitive   = true
}

variable "gpu_operator_version" {
  description = "NVIDIA GPU Operator Helm chart version. Only installed when at least one node in terraform-proxclus-vm-infra's nodes sets pcigpu; see modules/addons/gpu-operator."
  type        = string
  default     = "v26.7.0"
}

variable "enable_dcgm_exporter" {
  description = "Install dcgm-exporter (GPU metrics) alongside the GPU Operator. See modules/addons/gpu-operator."
  type        = bool
  default     = true
}

variable "enable_gfd" {
  description = "Install GPU Feature Discovery alongside the GPU Operator. See modules/addons/gpu-operator."
  type        = bool
  default     = false
}

variable "load_balancer_ip_range" {
  description = "Inclusive address range Cilium hands to LoadBalancer services. Must be free on the node subnet."

  type = object({
    start = string
    stop  = string
  })

  validation {
    condition = alltrue([
      can(cidrhost("${var.load_balancer_ip_range.start}/32", 0)),
      can(cidrhost("${var.load_balancer_ip_range.stop}/32", 0)),
    ])

    error_message = "load_balancer_ip_range start and stop must both be IPv4 addresses."
  }
}

variable "vm_infra_state_path" {
  description = "Path to terraform-proxclus-vm-infra's local state file, read for the node list and Talos schematic IDs"
  type        = string
  default     = "/home/yurick/terraform/state/vm-infra.tfstate"
}
