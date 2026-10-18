# GPU Operator Addon Module

Installs the [NVIDIA GPU Operator](https://github.com/NVIDIA/gpu-operator) so a
node with a GPU mapped in advertises an `nvidia.com/gpu` resource that pods can
request, and gives GPU workloads a way to opt into the containerd runtime the
GPU actually needs. Replaces the old `modules/addons/nvidia-device-plugin`
module, which installed only the community `nvidia-device-plugin` chart
by hand.

## Responsibilities

This module manages:

- the `gpu-operator` namespace (`var.namespace`), labelled
  `pod-security.kubernetes.io/enforce=privileged`
- `feature.node.kubernetes.io/pci-10de.present=true` and
  `var.gpu_node_label` (`nvidia.com/gpu.present=true` by default) labels on
  each Kubernetes Node that corresponds to one of `var.gpu_node_ips`
- the `gpu-operator` Helm release, with `driver`, `toolkit` and `nfd` all
  disabled, `devicePlugin` enabled, and `dcgmExporter`/`gfd` optional (see
  below)

The release itself then creates the `RuntimeClass` named
`var.runtime_class_name` (`nvidia` by default, handler `nvidia`) that GPU
pods request with `spec.runtimeClassName`, and the `nvidia.com/gpu` device
plugin DaemonSet.

It expects a bootstrapped cluster and the `helm`/`kubernetes` providers to be
configured by the caller. It does not touch machine configuration — the
kernel-module patch and image schematic that give the node a GPU driver in
the first place live in `modules/talos-cluster` and `schematic.tf` and are
selected by the same `pcigpu` field this module reads.

## Why `driver.enabled` and `toolkit.enabled` are both `false`

The GPU Operator normally installs and manages the NVIDIA driver and
container toolkit itself, which assumes a mutable host OS it can load kernel
modules and write containerd config into directly. On this cluster both are
already handled by Talos's own immutable-OS mechanism instead: the
`siderolabs/nvidia-open-gpu-kernel-modules-production` system extension
(selected via `schematic.tf`) provides the driver and
`modules/talos-cluster/patches/nvidia-modules.patch.yaml` loads its kernel
modules, while `siderolabs/nvidia-container-toolkit-production` registers the
`nvidia` containerd runtime. Letting the Operator's own driver/toolkit
installers run as well would have them fight the extensions for the same
kernel modules and containerd configuration.

## Why `nfd.enabled` is `false`

The Operator normally relies on Node Feature Discovery to auto-detect which
nodes have an NVIDIA GPU (via a `feature.node.kubernetes.io/pci-10de.present`
label NFD applies itself) and target its operand DaemonSets accordingly. This
repo already has a single, explicit source of truth for that fact —
`pcigpu` on a node in the root module's `var.nodes` — so NFD would only be a
second, independent way to reach the same conclusion, with no guarantee it
stays in sync with `pcigpu`. Instead, this module applies the same
`pci-10de.present` label itself, keyed off `var.gpu_node_ips`, and disables
NFD.

## Why nodes are matched by IP, not name

The root module's `var.nodes` knows each GPU node's Proxmox VM name and
static IP, but nothing pins the *Kubernetes* Node name to either: Talos
derives it from the node's hostname, which this cluster never sets
explicitly. Rather than assume the two line up, this module reads
`data.kubernetes_nodes` and matches each `var.gpu_node_ips` entry against the
Node's own reported `InternalIP`.

## `dcgmExporter` and `gfd`

`enable_dcgm_exporter` (default `true`) installs `dcgm-exporter` for GPU
utilization/memory/temperature metrics — one small extra pod, no dependency
on anything else being enabled. When `enable_prometheus` is also true, its
`ServiceMonitor` is created too and picked up automatically by
`module.prometheus` (see that module's
`serviceMonitorSelectorNilUsesHelmValues = false`); when `enable_prometheus`
is false, the `ServiceMonitor` is left out entirely, since its CRD wouldn't
exist yet.

`enable_gfd` (default `false`) installs GPU Feature Discovery, which labels
nodes with GPU model/driver/VBIOS details. Nothing in this repo consumes
those labels yet, so it's off by default; flip it on via `gpu_operator_extra_values`
or `enable_gfd` if a future workload needs to select on them.

## Inputs

- `gpu_node_ips`
- `gpu_operator_version`
- `namespace`
- `runtime_class_name`
- `gpu_node_label`
- `enable_dcgm_exporter`
- `enable_gfd`
- `enable_prometheus`
- `gpu_operator_extra_values`
- `helm_timeout`

## Outputs

- `runtime_class_name`
- `gpu_node_names`
- `namespace`

## Notes

Requesting the GPU from a workload takes two things on the pod spec, not
just the `nvidia.com/gpu` resource request:

```yaml
spec:
  runtimeClassName: nvidia
  containers:
    - name: cuda-workload
      resources:
        limits:
          nvidia.com/gpu: 1
```

Skipping `runtimeClassName` schedules the pod through the plain `runc`
runtime, which never sees the GPU even though the device plugin advertised
one.
