# Task runner for the cluster layer. Run `just --list` to see all recipes.
# terraform-proxclus-vm-infra must be applied first.

# OpenTofu by default. For Terraform: `TF=terraform just <recipe>` or
# `just tf=terraform <recipe>`. After changing tools, run `just switch` once.
tf := env("TF", "tofu")

plan:
    {{tf}} plan

# Install providers for the selected tool.
init:
    {{tf}} init -input=false

# Run once after changing tools. State written by tofu records
# registry.opentofu.org providers; left in place, Terraform would install those
# unpinned, ignoring versions.tf. tofu needs only the init.
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{tf}}" = terraform ]; then
      providers=$(terraform state pull | grep -oE 'registry\.opentofu\.org/[a-z0-9-]+/[a-z0-9-]+' | sort -u || true)
      for p in $providers; do
        terraform state replace-provider -auto-approve "$p" "registry.terraform.io/${p#registry.opentofu.org/}"
      done
    fi
    {{tf}} init -input=false

apply:
    {{tf}} apply -auto-approve

# Destroy the cluster and its addons (not the VMs; see vm-infra).
# The patch only runs if Longhorn's setting still exists: if the cluster or
# Longhorn is already gone (e.g. this is a re-run after a prior destroy got
# partway), there's nothing left for it to guard anyway.
destroy: apps-destroy
    if kubectl --kubeconfig .kube/config -n longhorn-system get settings.longhorn.io deleting-confirmation-flag --request-timeout=5s >/dev/null 2>&1; then \
      kubectl --kubeconfig .kube/config -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value":"true"}'; \
    fi
    {{tf}} destroy -auto-approve

# Delete ArgoCD's Applications while ArgoCD can still clear their finalizers;
# once it's uninstalled, they would hold its namespace in Terminating forever.
# The root goes first, or self-heal recreates the children. Finalizers still
# left (ArgoCD already gone, or the wait timed out) are stripped.
apps-destroy:
    #!/usr/bin/env bash
    set -uo pipefail
    k() { kubectl --kubeconfig .kube/config "$@"; }
    k --request-timeout=5s -n argocd get applications >/dev/null 2>&1 || exit 0

    if k --request-timeout=5s -n argocd get statefulset argocd-application-controller >/dev/null 2>&1; then
      k -n argocd delete application apps --ignore-not-found
      k -n argocd delete applications --all --timeout=300s
    else
      k -n argocd delete applications --all --wait=false
    fi
    for app in $(k -n argocd get applications -o name); do
      k -n argocd patch "$app" --type=merge -p '{"metadata":{"finalizers":null}}'
    done

fmt:
    {{tf}} fmt -recursive

# Write talosconfig and kubeconfig from Terraform outputs, then print the UIs.
generate: && endpoints postgres-secrets
    {{tf}} output -raw talosconfig > "$HOME/talosconfig"
    mkdir -p "$HOME/.kube"
    {{tf}} output -raw kubeconfig > "$HOME/.kube/config"
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

# Create the plain postgres app's credential Secrets if missing, then print them.
# Both sides share a password so the standby can replicate from the primary.
# They stay out of Git (the apps repo is public), so ArgoCD can't create them.
postgres-secrets:
    #!/usr/bin/env bash
    set -uo pipefail
    k() { kubectl --kubeconfig .kube/config --request-timeout=10s "$@"; }
    field() { k -n "postgres-$1" get secret "postgres-$1-credentials" -o jsonpath="{.data.$2}" 2>/dev/null | base64 -d; }

    pw=$(field primary POSTGRES_PASSWORD)
    [ -n "$pw" ] || pw=$(field standby POSTGRES_PASSWORD)
    [ -n "$pw" ] || pw=$(openssl rand -base64 24 | tr -d '/+=')

    for side in primary standby; do
      if ! k get namespace "postgres-$side" >/dev/null 2>&1; then
        echo "Postgres $side: <namespace not created yet; ArgoCD still syncing, re-run this>"
        continue
      fi
      if [ -z "$(field "$side" POSTGRES_PASSWORD)" ]; then
        k -n "postgres-$side" create secret generic "postgres-$side-credentials" \
          --from-literal=POSTGRES_DB=app \
          --from-literal=POSTGRES_USER=pgadmin \
          --from-literal=POSTGRES_PASSWORD="$pw" >/dev/null
      fi
      echo "Postgres $side:"
      echo "  database: $(field "$side" POSTGRES_DB)"
      echo "  user:     $(field "$side" POSTGRES_USER)"
      echo "  password: $(field "$side" POSTGRES_PASSWORD)"
    done
