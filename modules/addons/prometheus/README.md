# Prometheus Addon Module

Installs [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) —
Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics and a set
of default alerting rules/dashboards — for cluster monitoring.

## Responsibilities

This module manages:

- the `monitoring` namespace (`var.namespace`), labelled
  `pod-security.kubernetes.io/enforce=privileged`
- the `kube-prometheus-stack` Helm release into that namespace: Prometheus
  (via the Prometheus Operator the chart also installs), Alertmanager,
  Grafana, the `prometheus-node-exporter` DaemonSet, and `kube-state-metrics`

It expects a bootstrapped cluster and the `helm`/`kubernetes` providers to be
configured by the caller. It creates no namespace besides its own and needs
nothing from Talos machine configuration or the image schematic.

## Why the privileged namespace label

`prometheus-node-exporter` reads host-level CPU/memory/disk/network metrics
by running with `hostNetwork: true`, `hostPID: true`, and `hostPath` mounts of
`/proc` and `/sys` — all forbidden under the restricted Pod Security Standard.
This is the same shape of problem `modules/addons/longhorn` has with its
engine and CSI plugin pods, solved the same way: label the whole namespace
`privileged` rather than trying to scope it to just the exporter's pods.

Unlike Longhorn, none of this needs a Talos machine-config patch: `/proc` and
`/sys` are already present in every pod's mount namespace by default, so
nothing extra needs exposing from the host side.

## Why `serviceMonitorSelectorNilUsesHelmValues = false` (and the `podMonitor`/`rule` equivalents)

The chart's own default only lets Prometheus discover `ServiceMonitor`,
`PodMonitor` and `PrometheusRule` objects that carry this Helm release's own
label — meant for multi-tenant clusters where each Prometheus should only
scrape what it's explicitly told to. This cluster runs a single Prometheus
for everything on it, so all three are set to `false` here: any addon or app
that ships a `ServiceMonitor`/`PodMonitor`/`PrometheusRule` gets picked up
automatically, with no release label to remember to add.

## Inputs

- `kube_prometheus_stack_version`
- `namespace`
- `storage_class`
- `prometheus_storage_size`
- `prometheus_retention`
- `prometheus_service_type`
- `alertmanager_storage_size`
- `enable_grafana`
- `grafana_storage_size`
- `grafana_service_type`
- `grafana_admin_password`
- `kube_prometheus_stack_extra_values`
- `helm_timeout`

## Outputs

- `kube_prometheus_stack_version`
- `namespace`
- `prometheus_service_type`
- `grafana_service_type`

## Notes

`storage_class` defaults to `"longhorn"`, matching `apps/postgres-cnpg`'s own
default: it requires `enable_longhorn = true` on the root module. Without it
there is no StorageClass by that name, every PVC (Prometheus's, Alertmanager's
and Grafana's) stays `Pending`, and `helm_release.kube_prometheus_stack` times
out under its own `wait = true`.

`grafana_admin_password` defaults to the chart's own default
(`"prom-operator"`). Change it before leaving `grafana_service_type` at its
default of `LoadBalancer`, which puts Grafana's login page on the LAN.
