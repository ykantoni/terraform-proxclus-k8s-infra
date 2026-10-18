# Talos Kubernetes Cluster Module

Configures Talos Linux nodes and bootstraps Kubernetes.

## Responsibilities

This module manages:

- Talos machine secrets
- Talos client configuration
- control-plane configuration
- worker configuration
- static networking
- Talos configuration application
- cluster bootstrap
- kubeconfig generation
- two health gates dependents can rely on: a full Talos+Kubernetes check, and
  a narrower API-reachability probe

It does not create virtual machines, and it installs no CNI. With
`cni = "cilium"` it patches the control plane to deploy neither Flannel nor
kube-proxy, which leaves the cluster without pod networking until something
installs Cilium; see `modules/addons/cilium`.

## Addon prerequisites

Addons that need machine configuration reach it through `config_patches`,
`controlplane_config_patches` and `worker_config_patches`, so this module never
has to know which addons exist. Longhorn's kubelet mount, for example, lives in
`modules/addons/longhorn/patches/` and is passed in by the root module.

Those patches must be static YAML — a literal or `file()`. A value derived from
the running cluster would make the cluster depend on its own addons, which are
in turn deployed onto it.

## External access

By default every generated certificate only lists the nodes' LAN addresses
and `controlplane_vip` as valid SANs, so a client connecting from outside the
LAN — even once a router NATs a public IP through to `controlplane_vip` —
fails TLS verification: the address it dialed isn't one the certificate
knows about.

Setting `external_ip` (a public IP or a hostname that resolves to one) adds
it as an extra SAN: to every node's Talos API (`apid`) certificate, and, on
control-plane nodes only, to the Kubernetes API server certificate. That's
the only thing this module does for external access — it does not open any
port or configure the router's NAT/port-forward rule, which stays a manual
step outside Terraform. `talosconfig`/`kubeconfig` endpoints still default to
the nodes' LAN IPs, since that's what applies them; a client connecting
externally needs its own copy pointed at `external_ip` instead.

## Health gates

`data.talos_cluster_health` (`wait_for_health`) is the thorough check: Talos
boot stage on every node, plus the Kubernetes-level node-readiness, coredns
and kube-proxy checks. It is also the one that cannot pass on this cluster —
see the root README's "Known issue: nodes stuck at stage booting" — because
`ext-nvidia-persistenced` waits forever on GPU-less nodes that carry the
NVIDIA extensions anyway.

`terraform_data.wait_for_api` (`wait_for_api`) is narrower: it polls
`https://<controlplane_vip>:6443/version` until it gets any HTTP response, or
`api_wait_timeout` elapses. A 401 counts as ready — this cluster has anonymous
auth disabled, so every endpoint answers 401 once the API server is actually
up, and the probe treats that as proof of life rather than as an error;
only a connection-level failure (nothing listening yet) means "not ready".
That is all Helm-based addons actually need — proof the API server is
reachable — so it stays usable even with `wait_for_health` off. It runs via a
`local-exec` provisioner, so it needs `curl` on the machine running
`terraform apply`.

Provisioners only run once, at creation, so this polls exactly once per
cluster lifetime. A fresh `apply` after `terraform destroy` empties state and
recreates it, so the wait runs again; an incremental `apply` against a cluster
that is already up does not repeat it.

## Inputs

- `cluster_name`
- `talos_version`
- `talos_schematic_id`
- `gateway`
- `nameservers`
- `controlplane_vip`
- `external_ip`
- `cni`
- `kube_prism_port`
- `wait_for_health`
- `wait_for_api`, `api_wait_timeout`, `api_wait_interval`
- `config_patches`, `controlplane_config_patches`, `worker_config_patches`
- `nodes`

## Outputs

- `controlplane_ips`
- `worker_ips`
- `talosconfig`
- `kubeconfig`
