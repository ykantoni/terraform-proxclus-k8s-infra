# metrics-server Addon Module

Installs [metrics-server](https://github.com/kubernetes-sigs/metrics-server) so
`kubectl top node`/`kubectl top pod` and the HorizontalPodAutoscaler have
resource metrics to read.

## Responsibilities

This module manages:

- the `metrics-server` Helm release, into `var.namespace` (`kube-system` by
  default)

It expects a bootstrapped cluster and the `helm` provider to be configured by
the caller. It creates no namespace of its own and needs nothing from Talos
machine configuration or the image schematic.

## Why `--kubelet-insecure-tls` and `--kubelet-preferred-address-types`

metrics-server talks to each node's kubelet directly to scrape resource
metrics, and on Talos both of its defaults are wrong:

- it prefers the kubelet's `Hostname` address by default, but Talos nodes
  have no DNS-resolvable hostname — `--kubelet-preferred-address-types=InternalIP`
  makes it use the address that's actually reachable instead.
- the kubelet's serving certificate at that address is signed by the
  cluster's own CA, which isn't in metrics-server's trust store and isn't
  exposed anywhere this chart could pick it up from —
  `--kubelet-insecure-tls` skips verifying it. This is the standard
  workaround on Talos (and most kubeadm clusters), not a Talos-specific
  weakening: the connection is still TLS, only the certificate isn't
  checked against a CA.

## Inputs

- `metrics_server_version`
- `namespace`
- `metrics_server_extra_values`
- `helm_timeout`

## Outputs

- `metrics_server_version`
- `namespace`
