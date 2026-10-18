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

# Write talosconfig and kubeconfig from Terraform outputs, then print the UIs.
generate: && endpoints
    terraform output -raw talosconfig > "$HOME/talosconfig"
    mkdir -p "$HOME/.kube"
    terraform output -raw kubeconfig > "$HOME/.kube/config"
    chmod 600 "$HOME/talosconfig" "$HOME/.kube/config"

# Print ArgoCD, Grafana and Prometheus URLs and login credentials.
endpoints:
    #!/usr/bin/env bash
    set -uo pipefail
    k() { kubectl --kubeconfig .kube/config --request-timeout=10s "$@" 2>/dev/null; }
    lb() { k -n "$1" get svc "$2" -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; }
    secret() { k -n "$1" get secret "$2" -o jsonpath="{.data.$3}" | base64 -d; }

    ip=$(lb argocd argocd-server)
    echo "ArgoCD:     https://${ip:-<not installed>}"
    if [ -n "$ip" ]; then
      pw=$(secret argocd argocd-initial-admin-secret password)
      echo "  user:     admin"
      echo "  password: ${pw:-<initial secret deleted; password was rotated>}"
    fi

    ip=$(lb monitoring kube-prometheus-stack-grafana)
    echo "Grafana:    http://${ip:-<not installed>}"
    if [ -n "$ip" ]; then
      echo "  user:     $(secret monitoring kube-prometheus-stack-grafana admin-user)"
      echo "  password: $(secret monitoring kube-prometheus-stack-grafana admin-password)"
    fi

    ip=$(lb monitoring kube-prometheus-stack-prometheus)
    echo "Prometheus: http://${ip:-<not installed>}${ip:+:9090}  (no login)"
