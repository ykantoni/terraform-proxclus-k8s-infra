# ArgoCD Addon Module

Installs [ArgoCD](https://argo-cd.readthedocs.io/) via the
[argo-helm](https://github.com/argoproj/argo-helm) chart.

## Responsibilities

This module manages:

- the `argocd` namespace (`var.namespace`)
- the `argo-cd` Helm release, with `server.service.type` set to
  `var.argocd_service_type`
- when `var.apps_repo_url` is set, a root app-of-apps `Application`
  (`charts/argocd-root-app`) syncing `var.apps_repo_path` of that repo at
  `var.apps_repo_revision`

It expects a bootstrapped cluster and the `helm`/`kubernetes` providers to be
configured by the caller.

## Root Application

The root `Application` ships as a tiny local chart, the same way
`modules/addons/cilium`'s `cilium-lb-ipam` does: its CRD only exists once
`helm_release.argocd` has applied, so a `kubernetes_manifest` couldn't be
schema-checked at plan time. It syncs automatically with prune and self-heal,
and every manifest under `apps_repo_path` must itself be an `Application`.

It deliberately has no `resources-finalizer`: removing the root (its Helm
release being uninstalled or replaced) leaves the child Applications and
their workloads running instead of cascading deletes through every app.
The child Applications in the apps repo do carry the finalizer, so removing
one from Git deletes that app's workloads.

ArgoCD reads the repo from its remote, so only pushed commits deploy. A
public HTTPS repo needs no credentials; a private one needs a repository
secret in this namespace first.

## Why no privileged namespace label

Unlike `modules/addons/longhorn` or `modules/addons/prometheus`'s
node-exporter, none of ArgoCD's components (server, repo-server,
application-controller, redis, applicationset-controller,
notifications-controller, dex) need hostPath, hostNetwork, or other
privileged host access. The restricted Pod Security Standard is fine as-is,
so this namespace carries no `pod-security.kubernetes.io` labels.

## Why there's no Terraform-managed admin password

Grafana's chart (`modules/addons/prometheus`) takes a plain
`grafana_admin_password` value directly. ArgoCD's chart has no equivalent —
setting the admin password declaratively means supplying a bcrypt hash, not
plaintext, which is more machinery than it's worth here. Instead, this
module lets the chart do what it does by default: generate an initial admin
secret on install. Retrieve it after `terraform apply`:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Rotate it after first login (`argocd account update-password`) — the same
"don't leave the default in place" caveat this repo's `grafana_admin_password`
variable already carries for Grafana.

## Connecting

The UI/API serves HTTPS with a self-signed certificate by default (this
module doesn't set `server.insecure`, since this cluster has no reverse
proxy in front to terminate real TLS either way). Expect a browser warning
to click through, and use `--insecure` for the CLI:

```bash
argocd login <argocd-server LoadBalancer IP> --insecure
```

`var.argocd_service_type` defaults to `LoadBalancer`, the same as every
other UI in this cluster (Grafana, Hubble UI, Open WebUI) — see the root
README's "Networking" section. ArgoCD's UI/API is effectively
cluster-admin-capable (it can deploy anything to the cluster), so treat that
address and the admin credential with the same care as any other
cluster-admin access, not like Grafana's read-mostly dashboard.

## Inputs

- `argocd_version`
- `namespace`
- `argocd_service_type`
- `argocd_extra_values`
- `helm_timeout`
- `apps_repo_url`
- `apps_repo_revision`
- `apps_repo_path`
- `apps_root_app_name`

## Outputs

- `namespace`
- `argocd_service_type`
- `root_app_name`
