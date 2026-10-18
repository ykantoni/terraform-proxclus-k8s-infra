variable "argocd_version" {
  description = "argo-cd Helm chart version. Check https://github.com/argoproj/argo-helm/releases for the latest before relying on this default."
  type        = string
  default     = "10.10.5"
}

variable "namespace" {
  description = "Namespace ArgoCD is installed into"
  type        = string
  default     = "argocd"
}

variable "argocd_service_type" {
  description = "Kubernetes Service type argocd-server is exposed as. LoadBalancer (the default) gets an address from Cilium's load_balancer_ip_range, since this cluster runs no ingress controller; see the root README's \"Networking\" section. ArgoCD's UI/API is effectively cluster-admin-capable, so treat this address the same way as any other cluster-admin credential."
  type        = string
  default     = "LoadBalancer"
}

variable "argocd_extra_values" {
  description = "Extra argo-cd Helm values merged over the defaults"
  type        = any
  default     = {}
}

variable "helm_timeout" {
  description = "Seconds to wait for the ArgoCD release to become ready. Higher than the lighter addons' default: this chart installs several components (server, repo-server, application-controller, redis, applicationset-controller, notifications-controller, dex)."
  type        = number
  default     = 600
}
