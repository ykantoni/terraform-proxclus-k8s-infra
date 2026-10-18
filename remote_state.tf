# VMs and the Talos image schematics are owned by terraform-proxclus-vm-infra;
# this stack only reads them, so applying or destroying it never touches VMs.
# vm-infra must be applied first, or these outputs don't exist yet.
data "terraform_remote_state" "vm_infra" {
  backend = "local"

  config = {
    path = var.vm_infra_state_path
  }
}

locals {
  nodes = data.terraform_remote_state.vm_infra.outputs.nodes
}
