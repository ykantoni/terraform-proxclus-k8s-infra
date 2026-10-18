variable "metrics_server_version" {
  description = "metrics-server Helm chart version"
  type        = string
  default     = "3.14.0"
}

variable "namespace" {
  description = "Namespace metrics-server is installed into"
  type        = string
  default     = "kube-system"
}

variable "metrics_server_extra_values" {
  description = "Extra metrics-server Helm values merged over the defaults"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the metrics-server release to become ready"
  type        = number
  default     = 300
}
