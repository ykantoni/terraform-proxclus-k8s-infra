module "talos_cluster" {
  source = "./modules/talos-cluster"

  cluster_name              = var.cluster_name
  talos_version             = var.talos_version
  kubernetes_version        = var.kubernetes_version
  talos_schematic_id_common = data.terraform_remote_state.vm_infra.outputs.talos_schematic_id_common
  talos_schematic_id_gpu    = data.terraform_remote_state.vm_infra.outputs.talos_schematic_id_gpu
  gateway                   = var.gateway
  nameservers               = var.nameservers
  controlplane_vip          = var.controlplane_vip
  external_ip               = var.external_ip
  cni                       = var.cni
  kube_prism_port           = var.kube_prism_port
  wait_for_health           = var.wait_for_health
  wait_for_api              = var.wait_for_api

  config_patches = var.enable_longhorn ? [
    file("${path.module}/modules/addons/longhorn/patches/longhorn-mounts.patch.yaml")
  ] : []

  nodes = local.nodes
}

resource "local_sensitive_file" "kubeconfig" {
  filename = "${path.root}/.kube/config"
  content  = module.talos_cluster.kubeconfig

  file_permission      = "0600"
  directory_permission = "0700"
}
