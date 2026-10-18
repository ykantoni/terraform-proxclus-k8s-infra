locals {
  cilium_values = {
    # Pod IPs come from the podCIDR that kube-controller-manager hands each node.
    ipam = {
      mode = "kubernetes"
    }

    # Talos deploys no kube-proxy when cni is cilium, so Cilium must take over
    # service routing. L2 announcements also require it.
    kubeProxyReplacement = true

    # KubePrism fronts the control plane on every node, so Cilium keeps talking
    # to the API server even while it is the thing providing cluster networking.
    k8sServiceHost = var.k8s_service_host
    k8sServicePort = var.k8s_service_port

    # Talos mounts cgroupv2 and bpffs itself; Cilium must not remount them.
    cgroup = {
      autoMount = {
        enabled = false
      }

      hostRoot = "/sys/fs/cgroup"
    }

    # Talos forbids workloads from loading kernel modules, so SYS_MODULE is
    # dropped from Cilium's default capability set.
    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID",
        ]

        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE",
        ]
      }
    }

    # Answers ARP for LoadBalancer IPs so the pool is reachable on the LAN
    # without BGP.
    l2announcements = {
      enabled = true
    }

    # Leader election between announcing nodes is chatty against the API server.
    k8sClientRateLimit = {
      qps   = var.k8s_client_rate_limit.qps
      burst = var.k8s_client_rate_limit.burst
    }

    # Relay aggregates every agent's flow feed; the UI is the web dashboard
    # that talks to Relay. Both ride on hubble.enabled's flow visibility,
    # which is on by default in the chart.
    hubble = {
      relay = {
        enabled = var.enable_hubble_ui
      }

      ui = {
        enabled = var.enable_hubble_ui

        service = {
          type = var.hubble_ui_service_type
        }
      }
    }
  }
}

resource "helm_release" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version

  # Not wait=true: hubble.ui's Service defaults to LoadBalancer, and Helm's
  # wait blocks until that gets an external IP. That IP can only come from
  # cilium_lb_ipam below, which itself depends on this release - a deadlock
  # that would otherwise run until helm_timeout on every fresh install.
  wait    = false
  timeout = var.helm_timeout

  # Later entries win, so callers can override any of the defaults above.
  values = [
    yamlencode(local.cilium_values),
    yamlencode(var.cilium_extra_values),
  ]
}

# helm_release.cilium doesn't wait (see above), so the operator may not have
# registered these CRDs with the API server yet. Poll for them rather than
# depending on helm_release.cilium directly, or installing the chart below
# can race the operator and fail with "no matches for kind ... ensure CRDs
# are installed first".
resource "terraform_data" "wait_for_lb_ipam_crds" {
  depends_on = [
    helm_release.cilium
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      end=$(( $(date +%s) + ${var.crd_wait_timeout} ))
      until kubectl --kubeconfig '${var.kubeconfig_path}' get crd ciliumloadbalancerippools.cilium.io ciliuml2announcementpolicies.cilium.io >/dev/null 2>&1; do
        if [ "$(date +%s)" -ge "$end" ]; then
          echo "Cilium CRDs did not appear within ${var.crd_wait_timeout}s" >&2
          exit 1
        fi
        sleep ${var.crd_wait_interval}
      done
    EOT
  }
}

# Ships as a chart rather than as plain manifests because the CRDs it depends on
# are registered by the Cilium operator, and so do not exist at plan time.
resource "helm_release" "cilium_lb_ipam" {
  depends_on = [
    terraform_data.wait_for_lb_ipam_crds
  ]

  name      = "cilium-lb-ipam"
  namespace = "kube-system"

  chart = "${path.module}/charts/cilium-lb-ipam"

  values = [
    yamlencode({
      pool = {
        name  = var.lb_ipam_pool_name
        start = var.lb_ipam_range.start
        stop  = var.lb_ipam_range.stop
      }

      l2Announcements = {
        interfaces             = var.l2_announcement_interfaces
        announceOnControlPlane = var.l2_announce_on_control_plane
      }
    })
  ]
}
