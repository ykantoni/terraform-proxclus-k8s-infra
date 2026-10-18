# Cluster Addons Module

Installs the cluster addons that Talos deliberately leaves out once
`cni = "cilium"`.

## Responsibilities

This module manages:

- Cilium, as both CNI and kube-proxy replacement
- a `CiliumLoadBalancerIPPool` for LoadBalancer services
- a `CiliumL2AnnouncementPolicy` that advertises those addresses over ARP

It expects a bootstrapped cluster whose machine configuration already sets
`cluster.network.cni.name: none` and `cluster.proxy.disabled: true`, and it
expects the `helm` provider to be configured by the caller.

## Talos specifics

The Helm values deviate from Cilium's defaults in four ways, all forced by
Talos:

- `ipam.mode: kubernetes`, so pod addresses come from the node podCIDR
- `cgroup.autoMount.enabled: false`, because Talos already mounts cgroupv2 and
  bpffs
- `SYS_MODULE` dropped from the agent capabilities, because Talos does not let
  workloads load kernel modules
- `k8sServiceHost: localhost` with `k8sServicePort: 7445`, pointing Cilium at
  the node-local KubePrism proxy instead of a Service IP it would have to route
  itself

## Load balancer addressing

`lb_ipam_range` must be free on the same subnet as the nodes. Announcement is
ARP based, so an address outside the node subnet cannot be reached; it is not
routed anywhere. Nothing else may hand out those addresses either, so keep the
range outside any DHCP scope and away from the control-plane VIP.

By default only non-control-plane nodes answer ARP, since a node that claims an
address without hosting a backend still attracts the traffic.

Services pick up an address automatically. To request a specific one, set
`spec.loadBalancerIP` or the `io.cilium/lb-ipam-ips` annotation.

## Hubble

`enable_hubble_ui = true` (the default) turns on Hubble Relay and Hubble UI,
giving a web dashboard of the CNI's live traffic: the service map, L3/L4/L7
flows, DNS, and policy verdicts. Flow visibility itself (`hubble.enabled`) is
already on by default in the chart; Relay aggregates every agent's flow feed,
and the UI is the dashboard that talks to Relay.

`hubble_ui_service_type` (default `LoadBalancer`) controls how the UI is
exposed, the same as `lb_ipam_range` covers the rest of the cluster's
LoadBalancer services — see the root README's "Networking" section.

## Inputs

- `lb_ipam_range` — object with `start` and `stop` (required)
- `cilium_version`
- `k8s_service_host`, `k8s_service_port`
- `lb_ipam_pool_name`
- `l2_announcement_interfaces`
- `l2_announce_on_control_plane`
- `k8s_client_rate_limit`
- `enable_hubble_ui`
- `hubble_ui_service_type`
- `cilium_extra_values`
- `helm_timeout`

## Outputs

- `cilium_version`
- `load_balancer_ip_range`

## Notes

`CiliumLoadBalancerIPPool` is served at `cilium.io/v2`, while
`CiliumL2AnnouncementPolicy` is still `cilium.io/v2alpha1` as of Cilium 1.19.
Both CRDs are registered by the Cilium operator rather than by the chart, which
is why the pool ships as a nested chart applied after the Cilium release instead
of as a Terraform-managed manifest.
