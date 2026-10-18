# ArgoCD Addon Module

Installs [ArgoCD](https://argo-cd.readthedocs.io/) via the
[argo-helm](https://github.com/argoproj/argo-helm) chart.

## Responsibilities

This module manages:

- the `argocd` namespace (`var.namespace`)
- the `argo-cd` Helm release, with `server.service.type` set to
  `var.argocd_service_type`

It expects a bootstrapped cluster and the `helm`/`kubernetes` providers to be
configured by the caller.

## Scope: ArgoCD only, no app-of-apps yet

This module installs ArgoCD itself and nothing else — no root `Application`
resource, no git repo wired in. There's nothing to point it at yet. Adding
an app-of-apps bootstrap later is a natural, non-breaking follow-up: a root
`Application` manifest, applied the same way
`modules/addons/cilium`'s `cilium-lb-ipam` nested chart already handles
"apply a manifest after the chart that owns its CRDs is up" (`helm_release`
depending on `helm_release.argocd`, or a `kubectl_manifest`/`kubernetes_manifest`
resource once ArgoCD's `Application` CRD exists) — not something this module
needs restructuring to support.

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

## Outputs

- `namespace`
- `argocd_service_type`
