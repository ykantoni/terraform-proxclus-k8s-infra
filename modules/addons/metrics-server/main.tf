resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  namespace = var.namespace

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version

  wait    = true
  timeout = var.helm_timeout

  # Later entries win, so callers can override any of the defaults above.
  values = [
    yamlencode({
      args = [
        # Talos kubelets don't have a DNS-resolvable hostname, so the
        # Hostname address type metrics-server prefers by default never
        # connects; InternalIP is what's actually reachable.
        "--kubelet-preferred-address-types=InternalIP",

        # The kubelet serving certificate at that address is signed by the
        # cluster's own CA, which isn't in metrics-server's trust store and
        # isn't exposed anywhere this chart could pick it up from. Skipping
        # verification is the standard workaround on Talos (and most kubeadm
        # clusters) rather than a Talos-specific weakening.
        "--kubelet-insecure-tls",
      ]
    }),
    yamlencode(var.metrics_server_extra_values),
  ]
}
