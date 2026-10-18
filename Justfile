# Task runner for the cluster layer. Run `just --list` to see all recipes.
# terraform-proxclus-vm-infra must be applied first.

plan:
    terraform plan

apply:
    terraform apply -auto-approve

# Destroy the cluster and its addons (not the VMs; see vm-infra).
# The patch only runs if the apiserver is reachable: if the cluster's
# already gone (e.g. this is a re-run after a prior destroy succeeded),
# there's nothing left for Longhorn's setting to guard anyway.
destroy:
    if kubectl --kubeconfig .kube/config cluster-info --request-timeout=5s >/dev/null 2>&1; then \
      kubectl --kubeconfig .kube/config -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value":"true"}'; \
    fi
    terraform destroy -auto-approve

fmt:
    terraform fmt -recursive

# Write talosconfig and kubeconfig from Terraform outputs.
generate:
    terraform output -raw talosconfig > "$HOME/talosconfig"
    mkdir -p "$HOME/.kube"
    terraform output -raw kubeconfig > "$HOME/.kube/config"
    chmod 600 "$HOME/talosconfig" "$HOME/.kube/config"
