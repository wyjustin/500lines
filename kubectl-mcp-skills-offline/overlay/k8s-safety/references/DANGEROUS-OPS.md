# Dangerous operations

Classification used by `scripts/classify-op.py`. Names match kubectl-mcp-server tools.

## Classes

| Class | Meaning |
|-------|---------|
| `read` | Inspection only |
| `write` | Mutates cluster but is reversible / additive |
| `destructive` | Deletes or hard-stops capacity |

`destructive` ⊂ `write`.

## Destructive (block in `read_only`, `disable_destructive`, `confirm`)

```
delete_pod
delete_deployment
delete_statefulset
delete_daemonset
delete_service
delete_configmap
delete_secret
delete_namespace
delete_resource
uninstall_helm_chart
rollout_abort_tool
kubevirt_vm_stop
```

Also treat as destructive even if not in the server set:

- `kubectl_delete` with force, grace period 0, or cascade on Namespace/CRD/PV
- draining a node / deleting a Machine (CAPI) in production
- `helm uninstall` aliases

## Write (block only in `read_only`)

```
run_pod
scale_deployment
restart_deployment
rollback_deployment
create_deployment
update_deployment
scale_statefulset
restart_statefulset
delete_statefulset
restart_daemonset
create_service
update_service
create_configmap
update_configmap
create_secret
update_secret
create_namespace
install_helm_chart
upgrade_helm_chart
rollback_helm_release
apply_manifest
patch_resource
create_resource
replace_resource
switch_context
set_namespace_for_context
rollout_promote_tool
rollout_retry_tool
rollout_restart_tool
kubevirt_vm_start
kubevirt_vm_restart
kubevirt_vm_pause
kubevirt_vm_unpause
kubevirt_vm_migrate
capi_machinedeployment_scale_tool
```

`kubectl_exec` is **read** only if the command is clearly non-mutating
(`ls`, `env`, `cat` of non-secret files, `nslookup`). Treat
`rm`, package installs, process kills, and anything writing `/etc` or
application data as **write**, and refuse in `read_only`.

## Extra intercepts (skill-only, always confirm)

Even in `normal` mode, ask the user to restate context + namespace + name:

1. Any operation on `kube-system`, `kube-public`, `kube-node-lease`
2. Deleting or uninstalling ingress / CNI / CSI / cert-manager
3. `switch_context` when the destination name contains `prod` or `prd`
4. Scaling a Deployment or MachineDeployment to 0
5. `kubectl_apply` of a raw manifest the model generated but the user did not attach

## Response template when blocked

```
Blocked by k8s-safety (mode=<mode>, class=<class>, tool=<tool>).
Why: <one sentence>
Need from you: explicit confirmation with context, namespace, and resource name
— or switch the MCP server to a mode that allows this class.
Evidence already gathered: <bullets>
Next safe read: <tool>
```
