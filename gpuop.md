Manual apply runbook (run these yourself when ready)

cd /home/yurick/terraform/talos-proxmox

# 1. Review the plan carefully before applying anything.
#    Expect: destroy of the old nvidia-device-plugin release/namespace-scoped
#    resources (kube-system RuntimeClass "nvidia", the two node labels, the
#    helm_release), create of module.gpu_operator's namespace/labels/helm_release.
#    Nothing outside module.gpu_operator should appear in the plan.
terraform plan -out=gpu-operator.tfplan

# 2. Apply only after reviewing that plan.
terraform apply gpu-operator.tfplan

# 3. Verify the Operator came up clean.
kubectl get pods -n gpu-operator
kubectl get clusterpolicy -o jsonpath='{.items[0].status.state}'   # expect: ready
kubectl get runtimeclass nvidia                                    # handler: nvidia
kubectl get node w1 --show-labels | grep -o \
  'nvidia.com/gpu.present=true\|feature.node.kubernetes.io/pci-10de.present=true'
kubectl describe node w1 | grep 'nvidia.com/gpu'                   # allocatable: 1

# 4. apps/ollama has no code changes, but it's a separate Terraform state —
#    just confirm the pod is still scheduled and can see the GPU.
kubectl -n ollama get pods
kubectl exec -n ollama deploy/ollama -- nvidia-smi

# 5. If enable_dcgm_exporter and enable_prometheus are both true, confirm the
#    dcgm-exporter target is up in Prometheus and DCGM_FI_DEV_GPU_UTIL has
#    data in Grafana's Explore view.
If terraform plan shows anything you don't expect (e.g. touching apps/ollama, modules/talos-cluster, or the VM/passthrough resources), stop and don't apply — that would mean something in this plan's assumptions about the current cluster state doesn't hold, and is worth checking before proceeding.

Rollback, if the Operator doesn't come up cleanly: git checkout -- addons.tf variables.tf README.md && rm -rf modules/addons/gpu-operator && git checkout -- modules/addons/nvidia-device-plugin restores the working nvidia-device-plugin setup exactly as it was, then terraform apply again to reconcile the cluster back.