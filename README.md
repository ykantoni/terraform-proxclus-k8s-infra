# terraform-proxclus-k8s-infra

Talos Kubernetes cluster bootstrap and platform addons for the Proxmox
cluster whose VMs are built by
[terraform-proxclus-vm-infra](https://github.com/ykantoni/terraform-proxclus-vm-infra).

## Layout

- `modules/talos-cluster` — Talos machine configuration and cluster bootstrap
- `modules/addons/cilium` — Cilium and its LoadBalancer address pool
- `modules/addons/longhorn` — Longhorn, the default CSI provider for dynamic PVs
- `modules/addons/metrics-server` — metrics-server, for `kubectl top` and the
  HorizontalPodAutoscaler
- `modules/addons/prometheus` — kube-prometheus-stack
- `modules/addons/gpu-operator` — NVIDIA GPU Operator, so a mapped GPU shows up
  as an `nvidia.com/gpu` resource
- `modules/addons/argocd` — ArgoCD, for GitOps-managed apps
- `addons.tf` — where addons are composed
- `remote_state.tf` — reads the node list and Talos schematic IDs from
  vm-infra's state (`vm_infra_state_path`)

## Usage

vm-infra must be applied first: this stack reads its `nodes`,
`talos_schematic_id_common` and `talos_schematic_id_gpu` outputs from
`/home/yurick/terraform/state/vm-infra.tfstate`. Its own state is
`/home/yurick/terraform/state/k8s-infra.tfstate`.

```bash
just apply
just generate   # writes ~/talosconfig and ~/.kube/config
```

`terraform apply` also writes a kubeconfig to `.kube/config` inside this
directory, because the `helm` provider needs one to reach the cluster. The
stacks in terraform-proxclus-k8s-apps default their `kubeconfig_path` to it.

## Adding an addon

One module per addon under `modules/addons/`, instantiated in `addons.tf` with
its own enable flag. An addon owns everything it needs: its Helm release, its
namespace, any nested charts for custom resources, and its Talos patches.

Most addons are more than a Helm chart. `modules/addons/longhorn` is the
example: it needs `iscsi-tools` and `util-linux-tools` in the image schematic,
a `/var/lib/longhorn` kubelet mount in the machine configuration, a
`longhorn-system` namespace labelled `pod-security.kubernetes.io/enforce=privileged`,
and only then the chart. The machine-config half goes in
`modules/addons/<name>/patches/` and is passed to `module.talos_cluster` through
its `*_config_patches` inputs; keep those files static, or the cluster ends up
depending on its own addons.

Resist collapsing this into one generic map of charts. Namespace labels, custom
resources ordered after their CRDs, machine-config patches and ordering between
addons all need per-addon code.

## Networking

`cni = "cilium"` makes Talos deploy neither Flannel nor kube-proxy, and the
addons module installs Cilium to cover both roles. Set `cni = "flannel"` to fall
back to the Talos defaults.

LoadBalancer services get an address from `load_balancer_ip_range`, announced on
the LAN over ARP by Cilium L2 announcements. The range has to be free on the
node subnet: outside any DHCP scope, clear of the node addresses and of
`controlplane_vip`.

| Setting                  | Value                         |
| ------------------------ | ----------------------------- |
| Nodes                    | 192.168.1.201-192.168.1.204   |
| Control-plane VIP        | 192.168.1.99                  |
| LoadBalancer pool        | 192.168.1.60-192.168.1.98     |

Setting `external_ip` to a public IP or hostname adds it as a SAN on the
Talos and Kubernetes API certificates, so a client outside the LAN validates
TLS once it reaches the cluster. It doesn't configure the router: forwarding
that public IP's port 6443 (and 50000, for `talosctl`) to `controlplane_vip`
is a manual NAT/port-forward rule you set up separately, and the external
client needs its own `talosconfig`/`kubeconfig` with the endpoint changed to
`external_ip` — see `modules/talos-cluster/README.md`'s "External access"
section.

`enable_hubble_ui = true` (the default) installs Hubble Relay and Hubble UI
alongside Cilium: a web dashboard of the CNI's live traffic (service map,
L3/L4/L7 flows, DNS, policy verdicts). It gets its own LoadBalancer address
from the same pool, controlled by `hubble_ui_service_type`. Touches no machine
configuration and needs no reboot. See `modules/addons/cilium/README.md`'s
"Hubble" section for what the module sets.

## Storage

`enable_longhorn = true` installs Longhorn and makes its `longhorn`
StorageClass the cluster default, so PVCs provision dynamically without naming
`storageClassName`. It also adds a `/var/lib/longhorn` kubelet mount to every
node's machine configuration — turning it on for the first time reboots the
whole cluster, so it defaults to `false`. `iscsi-tools` and `util-linux-tools`,
which Longhorn's engine needs on the host, are already in
vm-infra's `customization-*.yaml` regardless of this flag.

`longhorn_version` and `longhorn_replica_count` (default 3, matching the
worker count) tune the release; see `modules/addons/longhorn/README.md` for
what else the module sets and why.

## Metrics

`enable_metrics_server = true` (the default) installs metrics-server, giving
`kubectl top node`/`kubectl top pod` and the HorizontalPodAutoscaler resource
metrics to read. Unlike `enable_longhorn`, it touches no machine
configuration and needs no reboot to turn on or off.

`metrics_server_version` tunes the chart version; see
`modules/addons/metrics-server/README.md` for the Talos-specific flags it
sets (`--kubelet-insecure-tls` and `--kubelet-preferred-address-types`) and
why they're needed.

## Monitoring

`enable_prometheus = true` (default `false`) installs
[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack):
Prometheus, Alertmanager, Grafana, node-exporter, and kube-state-metrics, with
default alerting rules and Kubernetes dashboards. Its PVCs default to the
`longhorn` StorageClass, so it also needs `enable_longhorn = true`; unlike
Longhorn itself, turning it on touches no machine configuration and needs no
reboot.

`kube_prometheus_stack_version` tunes the chart version, and
`grafana_admin_password` sets Grafana's login (defaults to the chart's own
`"prom-operator"` — change it before relying on the default LoadBalancer
exposure, which puts Grafana's login page on the LAN). See
`modules/addons/prometheus/README.md` for the rest of the module's inputs, the
privileged-namespace label node-exporter needs, and why
`serviceMonitorSelectorNilUsesHelmValues` (and its `podMonitor`/`rule`
equivalents) are turned off.

## GitOps

`enable_argocd = true` (default `false`) installs
[ArgoCD](https://argo-cd.readthedocs.io/) via the argo-helm chart. This is
ArgoCD plus one root app-of-apps `Application`, pointed at
`argocd_apps_repo_url` (default:
[terraform-proxclus-k8s-apps](https://github.com/ykantoni/terraform-proxclus-k8s-apps))
at `argocd_apps_repo_revision` (`main`), path `apps/`. From there ArgoCD
deploys every application; Terraform deploys none of them. Set
`argocd_apps_repo_url = ""` to install ArgoCD without the root app.

`argocd_service_type` defaults to `LoadBalancer`, the same as this cluster's
other UIs, and `argocd_version` tunes the chart version. ArgoCD's UI/API is
effectively cluster-admin-capable, so its LoadBalancer address and initial
admin credential (auto-generated by the chart, not Terraform-managed — see
the module README for retrieval) deserve more care than, say, Grafana's.

## GPU

Setting `pcigpu` on a node in vm-infra's `nodes` passes that PCI device through to
the VM (see vm-infra's `modules/proxmox-talos-vm`), boots it from the GPU image
schematic instead of the common one, and loads the NVIDIA kernel modules
(see vm-infra's `schematic.tf` and `modules/talos-cluster/patches/nvidia-modules.patch.yaml`).
Nothing else needs flipping: as soon as any node sets `pcigpu`,
`module.gpu_operator` installs the NVIDIA GPU Operator so that node's GPU
shows up as an `nvidia.com/gpu` resource for Kubernetes to schedule against,
and creates the `nvidia` `RuntimeClass` GPU pods must set via
`spec.runtimeClassName` to actually reach the GPU. See
`modules/addons/gpu-operator/README.md` for what the module sets and why,
including the pod-spec shape a GPU workload needs.

The Operator's own driver, container-toolkit and Node Feature Discovery
components are all disabled — Talos's `nvidia-open-gpu-kernel-modules-production`
and `nvidia-container-toolkit-production` system extensions already provide
the driver and the containerd runtime, and `pcigpu` is already this repo's
one source of truth for "this node has a GPU", so letting NFD auto-detect the
same fact independently would only be something else to keep in sync. It
still installs `dcgmExporter` (`enable_dcgm_exporter`, on by default) for GPU
metrics, picked up automatically by `module.prometheus` when
`enable_prometheus` is also on.

`gpu_operator_version` tunes the chart version; there's no matching enable
flag; unlike `enable_longhorn`, presence is derived entirely from `pcigpu`,
which is already the single source of truth this repo uses to decide the
schematic and kernel-module patch, so a second, independently toggled flag
would only be one more thing to keep in sync.

## Ordering

Bootstrapping only means Talos accepted the call, so the addons need
something else to gate on before the cluster is actually reachable. This
cluster uses two independent gates, both in `modules/talos-cluster`:

- `data.talos_cluster_health` (`wait_for_health`) — thorough, but currently
  off; see "Known issue" below.
- `terraform_data.wait_for_api` (`wait_for_api`, on by default) — polls
  `https://<controlplane_vip>:6443/version` until it gets any HTTP response
  (a 401 counts — this cluster has anonymous auth disabled, so every endpoint
  answers 401 once up), which is all Helm-based addons actually need. It runs
  once per cluster lifetime (a fresh build after `terraform destroy`
  re-triggers it) and needs `curl` on the machine running `terraform apply`.

Cilium, Longhorn, metrics-server, Prometheus, and the GPU Operator all depend
on `module.talos_cluster` as a whole, which is enough: a module-level
`depends_on` waits on every resource inside that module,
`terraform_data.wait_for_api` included, with no extra wiring needed in
`addons.tf`. Prometheus additionally depends on `module.longhorn` directly,
since its PVCs need Longhorn's CSI controller actually running to provision;
the GPU Operator additionally depends on `module.prometheus` directly, since
its `dcgmExporter` ServiceMonitor needs the Prometheus Operator's CRD to
already exist.

The Kubernetes-level checks stay enabled deliberately, because they are the only
ones that prove the API server answers requests. Talos skips the two that cannot
pass without a CNI — node readiness and coredns — as soon as the machine config
says `cni: none`, and the kube-proxy check skips itself when the DaemonSet is
gone. `skip_kubernetes_checks = true` would leave only Talos-level checks, none
of which touch Kubernetes.

`wait_for_health = false` disables the gate, which is also how you plan against
a cluster that is powered off.

### Known issue: nodes stuck at stage "booting"

`wait_for_health` is currently off. vm-infra's `customization-*.yaml` bakes the NVIDIA
extensions into the image used by every node, but only `worker1` has a GPU. On
the others `ext-nvidia-persistenced` waits forever for
`/sys/bus/pci/drivers/nvidia`, so the boot sequence never completes and Talos
reports stage `booting` even though every service is healthy:

```bash
talosctl -n 192.168.1.201 get machinestatus   # stage: booting, ready: true
talosctl -n 192.168.1.201 service             # ext-nvidia-persistenced Waiting
```

Kubernetes is unaffected — all nodes report `Ready`. What it does break is
anything that waits on Talos boot stage, including `talosctl health` and this
health check. Fixing it means giving GPU-less nodes an image without the NVIDIA
extensions, which is a separate schematic and a node upgrade.

The `helm` provider reads `.kube/config`, a file Terraform writes itself.
Because the provider is configured from the resource attribute rather than a
literal path, it is set up only after the file exists, and a single
`terraform apply` covers a cluster built from scratch.

## Migrating an existing cluster off Flannel

Talos stops rendering the Flannel and kube-proxy manifests once the new machine
configuration is applied, but it does not delete what it already created. After
`terraform apply`, remove the leftovers and restart everything that still holds
a Flannel address:

```bash
# Confirm Talos no longer manages either component.
talosctl -n 192.168.1.201 get manifests

kubectl -n kube-system delete daemonset kube-flannel kube-proxy
kubectl -n kube-system delete configmap kube-flannel-cfg kube-proxy

# Clear the iptables rules kube-proxy left behind, and give pods Cilium IPs.
talosctl -n 192.168.1.201,192.168.1.202,192.168.1.203,192.168.1.204 reboot
```

Then check that Cilium owns service routing:

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep -E 'KubeProxyReplacement|L2'
```

Expect `KubeProxyReplacement: True` and L2 announcements enabled. Pod networking
is down between the reboot and Cilium becoming ready.
