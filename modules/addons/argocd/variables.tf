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

variable "apps_repo_url" {
  description = "Git repo ArgoCD's root app-of-apps Application syncs from. Every manifest under apps_repo_path must be an Application. Empty string skips creating the root Application."
  type        = string
  default     = ""
}

variable "apps_repo_revision" {
  description = "Branch, tag or commit of apps_repo_url the root Application tracks"
  type        = string
  default     = "main"
}

variable "apps_repo_path" {
  description = "Directory in apps_repo_url holding the child Application manifests"
  type        = string
  default     = "apps"
}

variable "apps_root_app_name" {
  description = "Name of the root Application"
  type        = string
  default     = "apps"
}
