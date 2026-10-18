variable "gpu_node_ips" {
  description = "IPs of nodes that have a GPU mapped (pcigpu set), from the root module's var.nodes. Used to find each node's Kubernetes Node object and label it, so the Operator's operand DaemonSets only schedule onto nodes that actually have a GPU."
  type        = list(string)

  validation {
    condition     = length(var.gpu_node_ips) > 0
    error_message = "gpu_node_ips must not be empty; the caller should give this module a count of 0 instead of instantiating it with no GPU nodes."
  }
}

variable "gpu_operator_version" {
  description = "NVIDIA GPU Operator Helm chart version. Check https://github.com/NVIDIA/gpu-operator/releases for the latest before relying on this default."
  type        = string
  default     = "v26.7.0"
}

variable "namespace" {
  description = "Namespace the Operator and its operand DaemonSets are installed into"
  type        = string
  default     = "gpu-operator"
}

variable "runtime_class_name" {
  description = "Name of the Kubernetes RuntimeClass the Operator creates for GPU workloads (operator.runtimeClass), and the containerd runtime handler it points at. Must match the runtime name the siderolabs/nvidia-container-toolkit-production system extension registers with containerd, which is \"nvidia\"."
  type        = string
  default     = "nvidia"
}

variable "gpu_node_label" {
  description = "Label key applied to each Kubernetes Node in gpu_node_ips, alongside feature.node.kubernetes.io/pci-10de.present. Kept only so apps/ollama's gpu_node_selector default (\"nvidia.com/gpu.present\") keeps matching; the Operator itself is driven entirely by the pci-10de.present label once nfd is disabled."
  type        = string
  default     = "nvidia.com/gpu.present"
}

variable "enable_dcgm_exporter" {
  description = "Install dcgm-exporter (GPU utilization/memory/temperature metrics). When enable_prometheus is also true, its ServiceMonitor is created too and gets picked up automatically (see modules/addons/prometheus's serviceMonitorSelectorNilUsesHelmValues=false)."
  type        = bool
  default     = true
}

variable "enable_gfd" {
  description = "Install GPU Feature Discovery, which labels nodes with GPU model/driver/VBIOS details. Off by default: nothing in this repo consumes those labels yet."
  type        = bool
  default     = false
}

variable "enable_prometheus" {
  description = "Whether module.prometheus is enabled on the root module. Gates dcgmExporter.serviceMonitor so this module never tries to create a ServiceMonitor object before the Prometheus Operator's CRD for it exists."
  type        = bool
}

variable "gpu_operator_extra_values" {
  description = "Extra gpu-operator Helm values merged over the defaults"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the gpu-operator release to become ready"
  type        = number
  default     = 300
}
