# Longhorn Addon Module

Installs Longhorn as the cluster's default CSI provider, so PVCs provision
dynamically without naming a `storageClassName`.

## Responsibilities

This module manages:

- the `longhorn-system` namespace, labelled
  `pod-security.kubernetes.io/enforce=privileged`
- the Longhorn Helm release, with its `longhorn` StorageClass set as the
  cluster default

It expects a bootstrapped cluster and the `helm` provider to be configured by
the caller. It does not touch machine configuration; that half lives in
`patches/` and is applied by the root module through `module.talos_cluster`'s
`config_patches` input (see the root README's "Adding an addon" section).

## Talos specifics

Longhorn needs three things Talos does not provide by default, all handled
outside this module:

- `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` in
  `customization.yaml`, so `iscsid` and the block-device tooling Longhorn's
  engine shells out to exist on the host
- a `/var/lib/longhorn` kubelet bind mount, from
  `patches/longhorn-mounts.patch.yaml`, matching `var.data_path`
- the `longhorn-system` namespace's pod-security label, since Longhorn's
  engine and CSI plugin pods need privileged access to host block devices
  that the restricted Pod Security Standard forbids

The namespace is a `kubernetes_namespace` resource, not part of the Helm
release, because neither Helm-native option works here: Helm records a
release's Secret in its target namespace before applying that release's own
manifests, so a chart cannot create the namespace it installs into, and
`helm_release.longhorn`'s `create_namespace` flag creates a plain namespace
outside any release's ownership, which a `Namespace` object templated into the
chart would then collide with on install (an ownership-metadata conflict).
Managing it directly with the `kubernetes` provider sidesteps both and lets it
carry the pod-security label from the start.

## Inputs

- `longhorn_version`
- `namespace`
- `data_path`
- `replica_count`
- `longhorn_extra_values`
- `helm_timeout`

## Outputs

- `longhorn_version`
- `namespace`

## Notes

`data_path` and the bind mount in `patches/longhorn-mounts.patch.yaml` must
agree. The patch is static YAML — Terraform's `config_patches` input forbids
anything else, so it does not read `var.data_path` — so changing the data path
means editing both.

Machine-config patches only take effect on `terraform apply`, and Talos
reboots the node to apply them. Turning this addon on for the first time
reboots every node in the cluster.
