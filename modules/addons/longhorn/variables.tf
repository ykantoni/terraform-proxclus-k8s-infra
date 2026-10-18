variable "longhorn_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = "1.8.1"
}

variable "namespace" {
  description = "Namespace Longhorn is installed into. Gets pod-security.kubernetes.io/enforce=privileged, since Longhorn's engine and CSI plugin need privileged access to host block devices."
  type        = string
  default     = "longhorn-system"
}

variable "data_path" {
  description = "Path on each node's disk where Longhorn stores replica data. Must match the /var/lib/longhorn kubelet bind mount in modules/addons/longhorn/patches, which is static YAML and does not read this variable."
  type        = string
  default     = "/var/lib/longhorn"
}

variable "replica_count" {
  description = "Default number of replicas Longhorn keeps for each volume, and the default StorageClass's replica count"
  type        = number
  default     = 3
}

variable "longhorn_extra_values" {
  description = "Extra Longhorn Helm values merged over the defaults"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the Longhorn release to become ready"
  type        = number
  default     = 600
}
