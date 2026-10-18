variable "kube_prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version. Check https://github.com/prometheus-community/helm-charts/releases for the latest before relying on this default."
  type        = string
  default     = "90.0.0"
}

variable "namespace" {
  description = "Namespace Prometheus, Grafana, Alertmanager and their exporters are installed into. Gets pod-security.kubernetes.io/enforce=privileged, since the bundled prometheus-node-exporter DaemonSet needs hostNetwork, hostPID and hostPath mounts of /proc and /sys to read host-level metrics."
  type        = string
  default     = "monitoring"
}

variable "storage_class" {
  description = "StorageClass Prometheus's, Alertmanager's and Grafana's PVCs use. The default (\"longhorn\") requires enable_longhorn = true; without it there is no StorageClass by that name and every PVC stays Pending, which times out this module's helm_release under wait=true."
  type        = string
  default     = "longhorn"
}

variable "prometheus_storage_size" {
  description = "Size of the Prometheus server's PVC, holding its time-series data"
  type        = string
  default     = "20Gi"
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps time-series data before deleting it"
  type        = string
  default     = "15d"
}

variable "prometheus_service_type" {
  description = "Kubernetes Service type Prometheus's own web UI (port 9090) is exposed as. LoadBalancer (the default) gets an address from Cilium's load_balancer_ip_range, since this cluster runs no ingress controller; see the root README's \"Networking\" section."
  type        = string
  default     = "LoadBalancer"
}

variable "alertmanager_storage_size" {
  description = "Size of Alertmanager's PVC"
  type        = string
  default     = "2Gi"
}

variable "enable_grafana" {
  description = "Install the chart's bundled Grafana, pre-wired to this Prometheus with a set of default Kubernetes dashboards. Turn off if you already run Grafana elsewhere and only want Prometheus/Alertmanager."
  type        = bool
  default     = true
}

variable "grafana_storage_size" {
  description = "Size of Grafana's PVC, holding its sqlite database (dashboards, users, settings)"
  type        = string
  default     = "5Gi"
}

variable "grafana_service_type" {
  description = "Kubernetes Service type Grafana's web UI (port 80) is exposed as. LoadBalancer (the default) gets an address from Cilium's load_balancer_ip_range, since this cluster runs no ingress controller; see the root README's \"Networking\" section."
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_admin_password" {
  description = "Grafana admin login password. Defaults to the chart's own default (\"prom-operator\"); override before exposing grafana_service_type = LoadBalancer beyond a trusted LAN."
  type        = string
  default     = "prom-operator"
  sensitive   = true
}

variable "kube_prometheus_stack_extra_values" {
  description = "Extra kube-prometheus-stack Helm values merged over the defaults"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the kube-prometheus-stack release to become ready"
  type        = number
  default     = 600
}
